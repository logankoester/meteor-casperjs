Package.describe({
   name: 'ldk:casperjs',
   summary: 'CasperJS end to end test integration with velocity.',
   version: '0.1.8',
   git: 'https://github.com/logankoester/meteor-casperjs.git',
   debugOnly: true
});

Npm.depends({
   glob: '4.0.6',
   xml2js: '0.4.4'
});

Package.onUse(function(api) {
   api.versionsFrom('METEOR@1.0');
   api.use([
      'velocity:core@0.6.1',
      'velocity:shim@0.0.3',
      'coffeescript'
   ], 'server');
   api.addFiles('casperjs.coffee', 'server');
   api.addFiles('sample-tests/sampleTest.coffee', 'server', {isAsset: true});
});

Package.onTest(function(api) {
   api.use('tinytest');
   api.use('ldk:casperjs');
   api.addFiles('casperjs-tests.js');
});
