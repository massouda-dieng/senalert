'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "3cd1ef264078febae4a197d65fe97eff",
"version.json": "7c22ac2c8b8c42daaaa4c42effc497a4",
"index.html": "54c2907239d505e12d661e0b3cbc6adb",
"/": "54c2907239d505e12d661e0b3cbc6adb",
"main.dart.js": "3c5f5b4a80d75b785975fca6c7f898a2",
"flutter.js": "f393d3c16b631f36852323de8e583132",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "344a87a3478b58d85199a3f150869fa4",
"icons/Icon-maskable-192.png": "344a87a3478b58d85199a3f150869fa4",
"icons/Icon-maskable-512.png": "df6669be6e4e2b148f04faca8964cf74",
"icons/Icon-512.png": "df6669be6e4e2b148f04faca8964cf74",
"manifest.json": "b1cd122ab3f333ad530aba2478972176",
"assets/AssetManifest.json": "bc44e7336938cb5d72b6e5358876e124",
"assets/NOTICES": "8bf799bfcb757620b8a5ee3770f040db",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "294b5d3f672082ec6e5a1fa4a802ac96",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "cee9d771762b435845239cbd80b9df52",
"assets/fonts/MaterialIcons-Regular.otf": "7f02c2e0529b2127de6bb002a5c56a8d",
"assets/assets/images/accueil_agents.jpg": "08583d4d357bf2ad1f4277a1c166ee00",
"assets/assets/images/senalert_icone.png": "df6669be6e4e2b148f04faca8964cf74",
"assets/assets/images/senalert_logo.png": "894dbb56ca6262c9b930f6d9b6c84a65",
"assets/assets/images/photos/rue-inondee.jpg": "4833d7ac724f46a6ffe8c9ab5dc4b52e",
"assets/assets/images/photos/dakar-cote.jpg": "6b7054854b692d3e6389cbe617195c0f",
"assets/assets/images/photos/credits.json": "69d95124b6a2873e87a79f2ad70c182c",
"assets/assets/images/photos/croix-rouge-equipe.jpg": "f74059618ae0d2a7695b1f16c3a697f1",
"assets/assets/images/photos/senelec-agence.jpg": "696bc90a24d6baea228b94fc1a5ae107",
"assets/assets/images/photos/ambulance-pompiers.jpg": "080551526bb0ef73292700364d67955c",
"assets/assets/images/photos/pompiers-defile.jpg": "8d5a363c0306b0a3f4bb03495f03f95f",
"assets/assets/images/photos/police-vehicule.jpg": "4dd6b445655b2d9ec7a8d40981ebe78c",
"assets/assets/images/photos/incendie-fumee.jpg": "de8185188c460fe664f2f70e7d5d00e1",
"assets/assets/images/photos/pompiers-bnsp.jpg": "a38dbdf6006239647d209e770d23c7e7",
"assets/assets/images/photos/dakar-vue.jpg": "c80b3ba54296e6c25a4bf469e8941978",
"assets/assets/images/photos/dakar-coucher-soleil.jpg": "60419b6c5228229b665ca4b0ba14edfe",
"assets/assets/images/photos/camera-surveillance.jpg": "8cd57201c2a99be7f320c4e9ee2fc06f",
"assets/assets/images/photos/motards-sapeurs.jpg": "7b46782c8a5ed49552a19448c0166a11",
"assets/assets/images/photos/accident-route.jpg": "f688223e0ba0fe5e668e144638a7d167",
"assets/assets/images/photos/croix-rouge-agent.jpg": "4d1fdb312d1242eee4af259a432e0e96",
"assets/assets/data/fiches_secours.json": "1d680f78f7e586f694baf9d1c9fa9ed6",
"assets/assets/traductions/wolof.json": "c4624dab7cc2e85d026631b258fc099d",
"canvaskit/skwasm.js": "694fda5704053957c2594de355805228",
"canvaskit/skwasm.js.symbols": "262f4827a1317abb59d71d6c587a93e2",
"canvaskit/canvaskit.js.symbols": "48c83a2ce573d9692e8d970e288d75f7",
"canvaskit/skwasm.wasm": "9f0c0c02b82a910d12ce0543ec130e60",
"canvaskit/chromium/canvaskit.js.symbols": "a012ed99ccba193cf96bb2643003f6fc",
"canvaskit/chromium/canvaskit.js": "671c6b4f8fcc199dcc551c7bb125f239",
"canvaskit/chromium/canvaskit.wasm": "b1ac05b29c127d86df4bcfbf50dd902a",
"canvaskit/canvaskit.js": "66177750aff65a66cb07bb44b8c6422b",
"canvaskit/canvaskit.wasm": "1f237a213d7370cf95f443d896176460",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
