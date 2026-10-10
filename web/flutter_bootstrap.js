{{flutter_js}}
{{flutter_build_config}}

// Give each build its own bundle URL so an older cached preview cannot hide updates.
const errandlyBuild = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath && errandlyBuild) {
    build.mainJsPath += `?errandly_build=${encodeURIComponent(errandlyBuild)}`;
  }
}
_flutter.loader.load({
  serviceWorkerSettings: {serviceWorkerVersion: errandlyBuild}
});
