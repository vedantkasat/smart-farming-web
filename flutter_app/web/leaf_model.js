// TensorFlow.js runner for the leaf model, called from lib/leaf/engine_web.dart.
// Same loading as the original web app: model.json topology + float16 weights in weights.json.
window.leafModel = (() => {
  let model = null;
  return {
    async load(base) {
      if (model) return;
      if (!window.tf) throw new Error('TensorFlow.js did not load');
      const mj = await (await fetch(base + 'model.json')).json();
      const wj = await (await fetch(base + 'weights.json')).json();
      const bin = Uint8Array.from(atob(wj.b64), (c) => c.charCodeAt(0)).buffer;
      model = await tf.loadLayersModel(tf.io.fromMemory({
        modelTopology: mj.modelTopology,
        weightSpecs: mj.weightsManifest.flatMap((g) => g.weights),
        weightData: bin,
      }));
    },
    async predict(bytes) {
      const bmp = await createImageBitmap(new Blob([bytes]));
      const probs = tf.tidy(() => {
        const x = tf.image.resizeBilinear(tf.browser.fromPixels(bmp), [224, 224]).expandDims(0);
        return model.predict(x).dataSync();
      });
      bmp.close();
      return new Float32Array(probs);
    },
  };
})();
