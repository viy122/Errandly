<?php
declare(strict_types=1);

const PROOF_MAX_BYTES = 2 * 1024 * 1024;

function proofImage(string $bytes, string $name): array {
    if ($bytes === '' || strlen($bytes) > PROOF_MAX_BYTES) fail('Choose an image up to 2 MB.',413);
    $info = @getimagesizefromstring($bytes);
    if (!$info || !in_array($info['mime'],['image/jpeg','image/png','image/webp'],true)) fail('Choose a valid JPG, PNG or WebP image.');
    if ($info[0] < 1 || $info[1] < 1 || $info[0] * $info[1] > 20000000) fail('Choose an image with at most 20 megapixels.');
    $name = basename(str_replace('\\','/',$name));
    $name = preg_replace('/[\x00-\x1f\x7f]/u','',$name) ?? '';
    if ($name === '' || mb_strlen($name) > 180) fail('Choose a file with a shorter name.');
    return ['name'=>$name,'mime'=>$info['mime'],'size'=>strlen($bytes),'sha256'=>hash('sha256',$bytes),'bytes'=>$bytes];
}

function incomingProofFiles(): array {
    $files = [];
    foreach ($_FILES as $kind=>$file) {
        if (!in_array($kind,['receipt','item','delivery'],true) || !is_array($file) || is_array($file['error'] ?? null)) fail('Invalid proof attachment.');
        $error = $file['error'] ?? UPLOAD_ERR_NO_FILE;
        if ($error === UPLOAD_ERR_NO_FILE) continue;
        if (in_array($error,[UPLOAD_ERR_INI_SIZE,UPLOAD_ERR_FORM_SIZE],true)) fail('Choose an image up to 2 MB.',413);
        if ($error !== UPLOAD_ERR_OK) fail('The upload was interrupted. Choose your image and try again.');
        if (($file['size'] ?? 0) > PROOF_MAX_BYTES) fail('Choose an image up to 2 MB.',413);
        if (!is_uploaded_file($file['tmp_name'])) fail('Invalid uploaded file.');
        $bytes = file_get_contents($file['tmp_name']);
        if ($bytes === false) fail('Could not read the uploaded image.');
        $files[$kind] = proofImage($bytes,(string)$file['name']);
    }
    return $files;
}

function saveProofFiles(PDO $db, string $errand, string $user, array $files): bool {
    $changed = false;
    foreach ($files as $kind=>$file) {
        $existing = query($db,'SELECT id,sha256 FROM proof_files WHERE errand_id=? AND kind=?',[$errand,$kind])->fetch();
        if ($existing && hash_equals($existing['sha256'],$file['sha256'])) continue;
        // A replacement receives a new id, so viewers cannot display an older cached image.
        query($db,'DELETE FROM proof_files WHERE errand_id=? AND kind=?',[$errand,$kind]);
        query($db,'INSERT INTO proof_files(id,errand_id,kind,uploaded_by,file_name,mime_type,byte_size,sha256,payload) VALUES(?,?,?,?,?,?,?,?,?)',
            [bin2hex(random_bytes(16)),$errand,$kind,$user,$file['name'],$file['mime'],$file['size'],$file['sha256'],$file['bytes']]);
        $changed = true;
    }
    return $changed;
}

function privateProofFile(PDO $db, string $user, string $id): array {
    $file = query($db,'SELECT f.*,e.owner_id,e.runner_id FROM proof_files f JOIN errands e ON e.id=f.errand_id WHERE f.id=?',[$id])->fetch();
    if (!$file || ($file['owner_id'] !== $user && $file['runner_id'] !== $user && !isSupportUser($user))) fail('Proof image unavailable.',404);
    return $file;
}
