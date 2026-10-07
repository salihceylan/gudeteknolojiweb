{{flutter_js}}
{{flutter_build_config}}

// CanvasKit (1.5 MB wasm) varsayılan olarak Google'ın CDN'inden çekilir: kurumsal/engelli ağlarda site hiç
// açılmaz ve üçüncü taraf isteği oluşur. Derleme canvaskit/ klasörünü zaten build/web içine kopyalar; buradan yüklenir.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
