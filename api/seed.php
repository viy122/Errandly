<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
function seedDemo(PDO $db): void {
    // Seed once; never overwrite accounts, balances, jobs or expired deadlines.
    if ((int)query($db,'SELECT COUNT(*) FROM users')->fetchColumn() > 0) {
        echo "Demo seed skipped: database already has users.\n"; return;
    }
    $db->beginTransaction();
    try {
        foreach ([['ben','Ben Santos','Nasugbu, Batangas',450,1280,4.9,47],['anna','Anna Cruz','Nasugbu, Batangas',1500,420,4.8,23],['maria','Maria Reyes','Cebu City',1500,420,4.7,18],['joshua','Joshua Mendoza','Metro Manila',1500,420,4.6,31]] as $u) {
            query($db,'INSERT INTO users(id,email,password_hash,name,phone,location,bio,verified,rating,completed) VALUES(?,?,?,?,?,?,?,1,?,?)',
                [$u[0],$u[0] . '@example.com',password_hash('demo123',PASSWORD_DEFAULT),$u[1],'09171234567',$u[2],'A little help goes a long way. Happy to help with everyday errands!',$u[5],$u[6]]);
            query($db,'INSERT INTO wallets(user_id,available,total_earnings) VALUES(?,?,?)',[$u[0],$u[3],$u[4]]);
        }
        $rows = [
            ['anna','Buy 1 Yellow Pad','School Supplies','Campus Store, Nasugbu','CEA Building Room 204, Nasugbu',50,40,350,true,'Please buy an 80-sheet yellow pad and bring it to Room 204.','Nasugbu, Batangas'],
            ['maria','Print and deliver my documents','Printing','Print shop, Katipunan Avenue','UP Town Center, Quezon City',30,85,4200,false,'Print 15 pages, black and white, single-sided.','Quezon City'],
            ['joshua','Submit a document to the registrar','Document Submission','CEA Building, Nasugbu','Registrar Office, Nasugbu',0,30,450,false,'Drop off my signed enrollment form at Window 2.','Nasugbu, Batangas'],
            ['anna','Pick up my parcel','Pickup','Parcel collection point, Nasugbu','Barangay Bucana, Nasugbu',0,150,8500,true,'Collect my prepaid parcel and bring it to my home.','Nasugbu, Batangas'],
            ['maria','A little lunch rescue, please','Food','Food court, Ayala Center Cebu','Talamban, Cebu City',185,120,12000,false,'One chicken rice meal and bottled water.','Cebu City'],
            ['joshua','Deliver a book to my friend','Delivery','Poblacion, Makati City','BGC, Taguig City',0,100,6500,false,'Bring the wrapped book to the building reception.','Metro Manila'],
            ['anna','Queue at the government service center','Queueing','Service center, Nasugbu town proper','Service center, Nasugbu town proper',0,80,1000,false,'Hold my place for 30 minutes while I travel.','Nasugbu, Batangas'],
            ['maria','Deliver documents to another city','Delivery','Quezon City, Metro Manila','Dasmarinas, Cavite',0,450,65000,false,'Deliver a sealed document envelope tomorrow. Confirm travel arrangements in chat.','Metro Manila'],
            ['joshua','Pick up groceries for the weekend','Purchase','Public market, Davao City','Matina, Davao City',300,120,7000,false,'Buy the vegetables on my list. Upload a receipt and return any unused budget.','Davao City'],
            ['anna','Bring my charger across town','Others','Barangay Bucana, Nasugbu','Nasugbu town proper',0,100,11000,false,'Collect my charger from a friend and bring it to my office.','Nasugbu, Batangas'],
        ];
        foreach($rows as $i=>$r) {
            $id = 'e' . $i; $deadline = gmdate('Y-m-d H:i:s',time() + ($i === 7 ? 48 : $i+1)*3600);
            query($db,"INSERT INTO errands(id,owner_id,title,category,pickup,destination,budget,budget_currency,budget_method,fee,distance,urgent,description,area,transport,instructions,deadline,posted_at) VALUES(?,?,?,?,?,?,?,'PHP','GCash Simulation',?,?,?,?,?,?,?,?,?)",
                [$id,$r[0],$r[1],$r[2],$r[3],$r[4],$r[5],$r[6],$r[7],$r[8]?1:0,$r[9],$r[10],$r[7]>=1000?'Motorcycle':'On foot','Please message me when you arrive. Thank you!',$deadline,gmdate('Y-m-d H:i:s',time()-(4+$i*3)*60)]);
            $total = $r[6]+5;
            query($db,'UPDATE wallets SET available=available-? WHERE user_id=?',[$total,$r[0]]);
            ledger($db,$r[0],'Errand Payment',-$total,$r[1] . ' • secured',$id);
            if ($r[5] > 0) ledger($db,$r[0],'Purchase Funding',$r[5]*-1,$r[1] . ' • simulated peso funds secured separately',$id,'PHP');
        }
        foreach ([['ben','anna','friend'],['anna','ben','friend'],['ben','maria','friend'],['maria','ben','friend'],['ben','anna','favorite']] as $r) query($db,'INSERT INTO user_links(user_id,target_id,type) VALUES(?,?,?)',$r);
        ledger($db,'ben','Top Up',110,'GCash simulation');
        ledger($db,'ben','Runner Earnings',40,'Delivered a notebook');
        notice($db,'ben','Wallet','Your wallet is ready. You have 450 CY to get started.');
        notice($db,'ben','Errands','Welcome back! Someone could use a hand today.');
        query($db,'INSERT INTO messages(errand_id,sender_id,text) VALUES(?,?,?)',['e0','anna','Hi! Please make sure it is the yellow pad with 80 sheets. Thank you!']);
        $db->commit(); echo "Four demo accounts and 10 errands saved to MySQL.\n";
    } catch(Throwable $e) { $db->rollBack(); throw $e; }
}
