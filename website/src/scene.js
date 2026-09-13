import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { ease, foldState } from './motion.js';
import { createFoldRenderer } from './fold-renderer.js';
import { screenContent } from './screen-content.js';

export function createScene(container, interior, onReady, onFailure) {
  const renderer = new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.setClearColor(0x000000,0);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  container.appendChild(renderer.domElement);
  const world = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(22,innerWidth/innerHeight,0.01,100);
  const environment = new RoomEnvironment();
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environmentTarget = pmrem.fromScene(environment,0.04);
  world.environment = environmentTarget.texture;
  environment.dispose();pmrem.dispose();
  const key = new THREE.DirectionalLight(0xdbe8f1,2.5);key.position.set(-3,5,4);world.add(key);
  const rim = new THREE.DirectionalLight(0xc8d9e8,1.8);rim.position.set(4,3,-3);world.add(rim);
  const fold = createFoldRenderer(renderer);
  const screenCenter = new THREE.Vector3();
  const normal = new THREE.Vector3(0,0.340938,0.940086);
  const box = new THREE.Box3();
  let model,lid,screen,wallpaper,bounds;
  let screenHeight=2.1,screenWidth=3.4,lastOpening=0,lastInteractive=false;
  let disposed=false,failed=false,ready=false,contentGeneration=0,resizeTimer;

  function positionCamera(opening) {
    const distance = screenHeight/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov/2))*0.90);
    // On a phone, the lid is recognizable during the fold; only the final part
    // approaches the display closely enough for its content to fill the page.
    const widthFit = Math.max(1,screenWidth/screenHeight/camera.aspect*0.94);
    const approach = ease((opening-0.72)/0.28);
    camera.position.copy(screenCenter).addScaledVector(normal,distance*THREE.MathUtils.lerp(widthFit,1,approach));
    camera.lookAt(screenCenter);camera.updateMatrixWorld();
  }
  function projectedBounds() {
    const vertices=screen.geometry.attributes.position;
    let left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity;
    const point=new THREE.Vector3();
    for(let i=0;i<vertices.count;i++) {
      point.fromBufferAttribute(vertices,i).applyMatrix4(screen.matrixWorld).project(camera);
      const x=(point.x+1)*innerWidth/2,y=(1-point.y)*innerHeight/2;
      left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);
    }
    return {left,top,width:right-left,height:bottom-top};
  }
  function layoutContent() {
    lid.rotation.x=0;world.updateMatrixWorld(true);positionCamera(1);
    bounds=projectedBounds();
    const left=Math.max(12,bounds.left+1),top=Math.max(12,bounds.top+1);
    const right=Math.min(innerWidth-12,bounds.left+bounds.width-1);
    const bottom=Math.min(innerHeight-42,bounds.top+bounds.height-1);
    const style=document.documentElement.style;
    style.setProperty('--screen-left',`${left}px`);style.setProperty('--screen-top',`${top}px`);
    style.setProperty('--screen-width',`${right-left}px`);style.setProperty('--screen-height',`${bottom-top}px`);
    style.setProperty('--wallpaper-size',`${bounds.width}px ${bounds.height}px`);
    style.setProperty('--wallpaper-x',`${bounds.left-left}px`);style.setProperty('--wallpaper-y',`${bounds.top-top}px`);
  }
  async function refreshTexture() {
    if(!screen || !wallpaper || disposed) return;
    const generation=++contentGeneration;
    try {
      const canvas=await screenContent(interior,bounds,wallpaper);
      if(disposed || generation!==contentGeneration) return;
      fold.setSource(canvas);ready=true;
      render(lastOpening,lastInteractive);onReady();
    } catch(error) {
      if(disposed || generation!==contentGeneration) return;
      console.error('Could not prepare the display content.',error);failed=true;onFailure();
    }
  }
  function render(opening,interactive=false) {
    lastOpening=opening;lastInteractive=interactive;
    if(disposed || failed || !ready) return;
    const state=foldState(opening);
    lid.rotation.x=state.tilt;
    // Keep the real bezel and notch over the live HTML once fully open.
    fold.material.uniforms.live.value=interactive;
    positionCamera(opening);world.updateMatrixWorld(true);
    fold.render(state.effect);
    renderer.render(world,camera);
  }
  function resize() {
    renderer.setSize(innerWidth,innerHeight);
    camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();
    if(screen) {
      layoutContent();render(lastOpening,lastInteractive);
      clearTimeout(resizeTimer);resizeTimer=setTimeout(refreshTexture,120);
    }
  }
  resize();
  renderer.domElement.addEventListener('webglcontextlost',event=>{event.preventDefault();failed=true;onFailure();});
  const wallpaperPromise=new Promise((resolve,reject)=>{
    const image=new Image();image.onload=()=>resolve(image);image.onerror=reject;
    image.src=`${import.meta.env.BASE_URL}wallpaper.jpg`;
  });
  const modelPromise=new GLTFLoader().loadAsync(`${import.meta.env.BASE_URL}macbook.glb`);
  Promise.all([modelPromise,wallpaperPromise]).then(async([gltf,image])=>{
    if(disposed)return;
    model=gltf.scene;wallpaper=image;
    const scale=3.4/35.484545;
    model.scale.setScalar(scale);model.position.set(0,0.04-0.00764*scale,-0.4+12.42971*scale);
    lid=model.getObjectByName('CladofoldLid');screen=model.getObjectByName('CladofoldScreen');
    if(!lid || !screen)throw new Error('The lid model is incomplete.');
    model.getObjectByName('Base').visible=false;
    model.traverse(object=>{if(object.isMesh && object.material?.metalness!==undefined)object.material.envMapIntensity=0.5;});
    screen.material=fold.material;world.add(model);world.updateMatrixWorld(true);
    box.setFromObject(screen);box.getCenter(screenCenter);
    const size=box.getSize(new THREE.Vector3());screenHeight=Math.hypot(size.y,size.z);screenWidth=size.x;
    layoutContent();await refreshTexture();
  }).catch(()=>{if(!disposed){failed=true;onFailure();}});
  return {
    render,resize,refreshTexture,
    dispose(){
      disposed=true;contentGeneration++;clearTimeout(resizeTimer);
      world.traverse(object=>{object.geometry?.dispose();const materials=Array.isArray(object.material)?object.material:[object.material];for(const material of materials){if(!material || material===fold.material)continue;for(const value of Object.values(material))if(value?.isTexture)value.dispose();material.dispose();}});
      fold.dispose();environmentTarget.dispose();renderer.dispose();
    },
  };
}
