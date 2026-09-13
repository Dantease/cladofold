import * as THREE from 'three';

const vertex = `varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

// Project onto black first, then blur in two directions. The black participates
// in the blur, so borders frost inward instead of becoming hard cutouts.
export function createFoldRenderer(renderer) {
  const passScene = new THREE.Scene();
  const passCamera = new THREE.Camera();
  const geometry = new THREE.PlaneGeometry(2, 2);
  const quad = new THREE.Mesh(geometry);
  passScene.add(quad);
  const targets = Array.from({ length: 3 }, () => new THREE.WebGLRenderTarget(1024, 640, {
    depthBuffer: false, stencilBuffer: false,
    minFilter: THREE.LinearMipmapLinearFilter, magFilter: THREE.LinearFilter, generateMipmaps: true,
  }));
  const projection = new THREE.ShaderMaterial({
    vertexShader: vertex, depthTest: false, depthWrite: false,
    uniforms: { source: { value: null }, fold: { value: 0 } },
    fragmentShader: `
      uniform sampler2D source; uniform float fold; varying vec2 vUv;
      void main() {
        float p = fold;
        if (p < 0.00001) { gl_FragColor = texture2D(source, vUv); return; }
        float tilt = p * 1.50796447;
        float depth = 0.35 * sin(tilt);
        float divisor = cos(tilt) + depth;
        float height = max(1.0 + 0.18 * p, 1.0 / divisor);
        float inset = 0.5 * depth / divisor;
        float topWidth = max(0.025, 1.0 - 2.0 * inset);
        float denominator = height - (1.0 - topWidth) * vUv.y;
        // Inverse homography of the hinge-anchored trapezoid.
        float y = topWidth * vUv.y / max(0.001, denominator);
        float x = (vUv.x - 0.5) / max(0.01, 1.0 - 2.0 * inset * vUv.y / height) + 0.5;
        vec2 uv = vec2(x, y);
        if (x < 0.0 || x > 1.0 || y < 0.0 || y > 1.0) gl_FragColor = vec4(0.0,0.0,0.0,1.0);
        else gl_FragColor = texture2D(source, uv);
      }`,
  });
  const blur = new THREE.ShaderMaterial({
    vertexShader: vertex, depthTest: false, depthWrite: false,
    uniforms: {
      source: { value: null }, fold: { value: 0 },
      direction: { value: new THREE.Vector2(1, 0) }, texel: { value: new THREE.Vector2(1/1024, 1/640) },
    },
    fragmentShader: `
      uniform sampler2D source; uniform float fold;
      uniform vec2 direction; uniform vec2 texel; varying vec2 vUv;
      void main() {
        float sigma = 42.0 * fold * mix(0.035, 1.0, pow(vUv.y, 0.85));
        vec3 sum = vec3(0.0); float total = 0.0;
        for (int i = -12; i <= 12; i++) {
          float distance = float(i) * 0.25;
          float weight = exp(-0.5 * distance * distance);
          vec2 uv = vUv + direction * texel * sigma * distance;
          // Extend vertically to avoid an artificial top-edge dark strip.
          float sampleLevel = max(0.0, log2(max(1.0, sigma * 0.25)));
          vec3 color = textureLod(source, clamp(uv, vec2(0.0), vec2(1.0)), sampleLevel).rgb;
          sum += color * weight; total += weight;
        }
        gl_FragColor = vec4(sum / total, 1.0);
      }`,
  });
  const display = new THREE.ShaderMaterial({
    uniforms: { source: { value: targets[2].texture }, fold: { value: 0 }, live: { value: false }, scrollPhase: { value: 0 }, scrollGlow: { value: 0 } },
    vertexShader: `varying vec2 vUv; void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}`,
    fragmentShader: `uniform sampler2D source; uniform float fold; uniform bool live;
      uniform float scrollPhase; uniform float scrollGlow; varying vec2 vUv;
      void main() {
        if (live) {
          // Soft glass reflections use the existing display mesh and context.
          // Their phase comes only from scroll position; there is no idle loop.
          float curve = vUv.x + 0.22 * sin(vUv.y * 4.5 + scrollPhase * 5.0);
          float ribbon = exp(-pow((curve - mix(-0.15, 1.15, scrollPhase)) * 5.5, 2.0));
          float halo = exp(-pow((curve - mix(0.85, 0.15, scrollPhase)) * 2.8, 2.0));
          float alpha = (ribbon * 0.09 + halo * 0.025) * scrollGlow;
          vec3 tint = mix(vec3(0.58, 0.76, 0.91), vec3(0.78, 0.90, 0.57), scrollPhase);
          // The transparent canvas composites premultiplied color over the HTML.
          gl_FragColor = vec4(tint * alpha, alpha);
          return;
        }
        vec3 color = texture2D(source, vUv).rgb;
        float p = fold;
        float closure = 1.0 - smoothstep(0.86, 1.0, p);
        float shade = (1.0 - 0.10*p) * mix(1.0, 1.0 - 0.68*pow(p,1.2), vUv.y);
        gl_FragColor = vec4(color * shade * closure, 1.0);
        #include <colorspace_fragment>
      }`,
    toneMapped: false,
  });
  let source, previous = -1;
  function pass(material, target) {
    quad.material = material;
    renderer.setRenderTarget(target);
    renderer.render(passScene, passCamera);
  }
  return {
    material: display,
    setSource(canvas) {
      source?.dispose();
      source = new THREE.CanvasTexture(canvas);
      source.colorSpace = THREE.SRGBColorSpace;
      source.minFilter = THREE.LinearFilter;
      source.generateMipmaps = false;
      projection.uniforms.source.value = source;
      previous = -1;
    },
    render(progress) {
      if (!source || Math.abs(previous-progress) < 0.00001) return;
      previous = progress;
      const previousTarget = renderer.getRenderTarget();
      projection.uniforms.fold.value = progress;
      pass(projection, targets[0]);
      blur.uniforms.fold.value = progress;
      blur.uniforms.source.value = targets[0].texture;
      blur.uniforms.direction.value.set(1,0);
      pass(blur, targets[1]);
      blur.uniforms.source.value = targets[1].texture;
      blur.uniforms.direction.value.set(0,1);
      pass(blur, targets[2]);
      display.uniforms.fold.value = progress;
      renderer.setRenderTarget(previousTarget);
    },
    dispose() { source?.dispose();targets.forEach(t=>t.dispose());projection.dispose();blur.dispose();display.dispose();geometry.dispose(); },
  };
}
