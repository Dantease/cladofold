import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { clamp, ease } from './motion.js';

function screenTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 1440; canvas.height = 900;
  const c = canvas.getContext('2d');
  c.fillStyle = '#090b09'; c.fillRect(0,0,1440,900);
  c.fillStyle = '#f4f2ea'; c.font = '900 50px Arial'; c.fillText('cf',80,104);
  c.fillStyle = '#c6f542'; c.fillText('.',123,104);
  c.textAlign = 'right'; c.font = '22px Arial'; c.fillStyle = '#dadcd3'; c.fillText('☆  Star on GitHub',1350,95);
  c.textAlign = 'center'; c.font = '20px Arial'; c.fillStyle = '#999f90'; c.fillText('A LITTLE DETAIL. EVERY DAY.',720,247);
  c.fillStyle = '#f4f2ea'; c.font = '600 108px Arial'; c.fillText('a softer close.',720,391);
  c.fillStyle = '#c6f542'; c.fillText('a clearer open.',720,507);
  c.fillStyle = '#c2c4bc'; c.font = '25px Arial'; c.fillText('A little blur. A little wonder. All in the movement of your lid.',720,580);
  c.fillStyle = '#c6f542'; c.beginPath(); c.roundRect(500,629,440,74,8); c.fill();
  c.fillStyle = '#151a0a'; c.font = '600 23px Arial'; c.fillText('Download for Mac     ↓',720,675);
  c.fillStyle = '#999d91'; c.font = '18px Arial'; c.fillText('Free preview · macOS 14+',720,747);
  c.fillStyle = '#c3c7bb'; c.font = '20px Arial'; c.fillText('Will it work on my Mac?',720,790);
  c.strokeStyle = '#282d25'; c.beginPath(); c.moveTo(80,840); c.lineTo(1360,840); c.stroke();
  c.font = '17px Arial'; c.textAlign = 'left'; c.fillStyle = '#8f9587'; c.fillText('Small app. Softer edges.',80,879);
  c.textAlign = 'right'; c.fillStyle = '#c6f542'; c.fillText('Get cladofold. ↓',1360,879);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function foldMaterial() {
  return new THREE.ShaderMaterial({
    uniforms: { source: { value: screenTexture() }, fold: { value: 1 }, interactive: { value: 0 } },
    vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
    fragmentShader: `
      uniform sampler2D source; uniform float fold; uniform float interactive; varying vec2 vUv;
      vec3 projected(vec2 uv, float p) {
        float tilt=p*1.50796447;
        float depth=0.2821*sin(tilt);
        float divisor=cos(tilt)+depth;
        float radius=36.0*p*1440.0/1512.0;
        float height=max(1.0+max(2.0,radius*3.0)/900.0,1.0/divisor);
        float y=uv.y/height;
        float inset=0.5*depth/divisor;
        float x=(uv.x-0.5)/max(0.01,1.0-2.0*inset*y)+0.5;
        if(x<0.0 || x>1.0 || y<0.0 || y>1.0) return vec3(0.0);
        return texture2D(source,vec2(x,y)).rgb;
      }
      void main(){
        float p=clamp(fold,0.0,1.0);
        if(interactive>0.5){ gl_FragColor=vec4(0.002732,0.003347,0.002732,1.0); }
        else if(p>=0.9999){gl_FragColor=vec4(0.0,0.0,0.0,1.0);}
        else if(p<0.0001){gl_FragColor=texture2D(source,vUv);}
        else {
          float radius=36.0*p*1440.0/1512.0*mix(0.025,1.0,vUv.y);
          vec2 r=vec2(radius/1440.0,radius/900.0);
          vec3 color=projected(vUv,p)*0.227027;
          color+=(projected(vUv+vec2(r.x,0.0),p)+projected(vUv-vec2(r.x,0.0),p)+projected(vUv+vec2(0.0,r.y),p)+projected(vUv-vec2(0.0,r.y),p))*0.121622;
          color+=(projected(vUv+r*1.6,p)+projected(vUv-r*1.6,p)+projected(vUv+vec2(r.x,-r.y)*1.6,p)+projected(vUv+vec2(-r.x,r.y)*1.6,p))*0.071622;
          float tail=clamp((p-0.88)/0.12,0.0,1.0);
          float closure=1.0-tail*tail*(3.0-2.0*tail);
          float shade=(1.0-0.2*p)*closure*mix(1.0,1.0-0.8*pow(p,1.15),vUv.y);
          gl_FragColor=vec4(color*shade,1.0);
        }
        #include <colorspace_fragment>
      }`,
    toneMapped: false,
  });
}

export function createScene(container, onReady, onFailure) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.setClearColor(0x000000,1);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.15;
  container.appendChild(renderer.domElement);
  const world = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(36, innerWidth/innerHeight,0.01,100);
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environment = new RoomEnvironment();
  const environmentTarget = pmrem.fromScene(environment,0.04);
  world.environment = environmentTarget.texture;
  environment.dispose(); pmrem.dispose();
  const key = new THREE.DirectionalLight(0xf0f3ed,4); key.position.set(-3,5,4); world.add(key);
  const rim = new THREE.DirectionalLight(0xb9c8d9,3); rim.position.set(4,4,-3); world.add(rim);
  world.add(new THREE.AmbientLight(0xffffff,0.3));
  const material = foldMaterial();
  const endCenter = new THREE.Vector3(0,1.1,-0.7);
  const endNormal = new THREE.Vector3(0,0.340938,0.940086);
  const startEye = new THREE.Vector3(0,3.5,6.5);
  const startLook = new THREE.Vector3(0,0.3,0.55);
  const responsiveStart = new THREE.Vector3();
  const endEye = new THREE.Vector3();
  const look = new THREE.Vector3();
  const box = new THREE.Box3();
  let model, lid, screen, screenHeight = 2.1, lastOpening=0, lastInteractive=false, disposed=false, failed=false;

  function layoutInterior() {
    if (!screen) return;
    let left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity;
    const vertices = screen.geometry.attributes.position;
    for (let i=0;i<vertices.count;i++) {
      const point = new THREE.Vector3().fromBufferAttribute(vertices,i).applyMatrix4(screen.matrixWorld).project(camera);
      const px=(point.x+1)*innerWidth/2, py=(1-point.y)*innerHeight/2;
      left=Math.min(left,px);right=Math.max(right,px);top=Math.min(top,py);bottom=Math.max(bottom,py);
    }
    left=Math.max(12,left+2);right=Math.min(innerWidth-12,right-2);
    top=Math.max(12,top+2);bottom=Math.min(innerHeight-40,bottom-2);
    const style = document.documentElement.style;
    style.setProperty('--screen-left',`${left}px`);style.setProperty('--screen-top',`${top}px`);
    style.setProperty('--screen-width',`${Math.max(200,right-left)}px`);style.setProperty('--screen-height',`${Math.max(250,bottom-top)}px`);
  }
  function render(opening, interactive=false) {
    lastOpening=opening;lastInteractive=interactive;
    if(disposed || failed) return;
    const lidOpen = ease(opening/0.82);
    const zoom = ease((opening-0.4)/0.6);
    if(lid) lid.rotation.x=1.905*(1-lidOpen);
    if(model) model.rotation.y=-0.1*(1-zoom);
    material.uniforms.fold.value=1-lidOpen;
    material.uniforms.interactive.value=interactive?1:0;
    const distance=screenHeight/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov/2))*0.92);
    endEye.copy(endCenter).addScaledVector(endNormal,distance);
    responsiveStart.copy(startEye).sub(startLook).multiplyScalar(Math.max(1,0.95/camera.aspect)).add(startLook);
    camera.position.lerpVectors(responsiveStart,endEye,zoom);
    look.lerpVectors(startLook,endCenter,zoom);camera.lookAt(look);camera.updateMatrixWorld();
    world.updateMatrixWorld(true);
    if(interactive) layoutInterior();
    renderer.render(world,camera);
  }
  function resize(){renderer.setSize(innerWidth,innerHeight);camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();}
  resize();
  renderer.domElement.addEventListener('webglcontextlost', event => { event.preventDefault();failed=true;onFailure(); });
  new GLTFLoader().load(`${import.meta.env.BASE_URL}macbook.glb`, gltf => {
    if(disposed) return;
    model=gltf.scene;
    const scale=3.4/35.484545;
    model.scale.setScalar(scale);model.position.set(0,0.04-0.00764*scale,-0.4+12.42971*scale);
    lid=model.getObjectByName('CladofoldLid');screen=model.getObjectByName('CladofoldScreen');
    if(!lid || !screen){failed=true;onFailure();return;}
    model.traverse(object=>{if(object.isMesh){object.frustumCulled=true;if(object.material?.metalness!==undefined){object.material.envMapIntensity=0.65;}}});
    screen.material=material;world.add(model);world.updateMatrixWorld(true);
    box.setFromObject(screen);box.getCenter(endCenter);
    const size=box.getSize(new THREE.Vector3());screenHeight=Math.hypot(size.y,size.z);
    render(lastOpening,lastInteractive);onReady();
  }, undefined, ()=>{failed=true;onFailure();});
  return { render,resize,dispose(){disposed=true;world.traverse(object=>{object.geometry?.dispose();const materials=Array.isArray(object.material)?object.material:[object.material];for(const m of materials){if(!m)continue;for(const value of Object.values(m))if(value?.isTexture)value.dispose();m.dispose();}});material.uniforms.source.value.dispose();environmentTarget.dispose();renderer.dispose();} };
}
