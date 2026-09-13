import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { foldState } from './motion.js';
import { createFoldRenderer } from './fold-renderer.js';
import { screenContent } from './screen-content.js';

export function createScene(container, interior, onReady, onFailure) {
  const renderer = new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.setClearColor(0x000000,0);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  container.appendChild(renderer.domElement);
  const world = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(22,1,0.01,100);
  const environment = new RoomEnvironment();
  const pmrem = new THREE.PMREMGenerator(renderer);
  const environmentTarget = pmrem.fromScene(environment,0.04);
  world.environment = environmentTarget.texture;
  environment.dispose();pmrem.dispose();
  const key = new THREE.DirectionalLight(0xdbe8f1,2.5);key.position.set(-3,5,4);world.add(key);
  const rim = new THREE.DirectionalLight(0xc8d9e8,1.8);rim.position.set(4,3,-3);world.add(rim);
  const fold = createFoldRenderer(renderer);
  const frameCenter = new THREE.Vector3();
  const normal = new THREE.Vector3(0,0.340938,0.940086);
  const up = new THREE.Vector3(0,normal.z,-normal.y);
  const box = new THREE.Box3();
  const modelScale=3.4/35.484545;
  let model,lid,screen,wallpaper,bounds;
  let viewWidth=innerWidth,viewHeight=innerHeight-40,openDistance=6,lastOpening=0,lastInteractive=false;
  let disposed=false,failed=false,ready=false,contentGeneration=0,resizeTimer;

  function positionCamera() {
    camera.position.copy(frameCenter).addScaledVector(normal,openDistance);
    camera.lookAt(frameCenter);camera.updateMatrixWorld();
  }
  function projectedBounds(root=screen) {
    let left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity;
    const point=new THREE.Vector3();
    root.traverse(object=>{
      const vertices=object.geometry?.attributes.position;
      if(!vertices)return;
      for(let i=0;i<vertices.count;i++) {
        point.fromBufferAttribute(vertices,i).applyMatrix4(object.matrixWorld).project(camera);
        const x=(point.x+1)*viewWidth/2,y=(1-point.y)*viewHeight/2;
        left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);
      }
    });
    return {left,top,width:right-left,height:bottom-top};
  }
  function fitFrame() {
    // The display acts as the page, so adapt the lid's width to the viewport
    // instead of cropping away its sides or leaving a wide black surround.
    const gap=viewWidth<700?6:10;
    model.scale.setScalar(modelScale);lid.rotation.x=0;world.updateMatrixWorld(true);
    box.setFromObject(lid);box.getCenter(frameCenter);
    const size=box.getSize(new THREE.Vector3());
    openDistance=Math.hypot(size.y,size.z)/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov/2)));
    positionCamera();
    for(let i=0;i<2;i++) {
      const frame=projectedBounds(lid);
      openDistance*=frame.height/(viewHeight-2*gap);
      positionCamera();
    }
    const frame=projectedBounds(lid);
    model.scale.x*= (viewWidth-2*gap)/frame.width;
    const unitsPerPixel=2*openDistance*Math.tan(THREE.MathUtils.degToRad(camera.fov/2))/viewHeight;
    frameCenter.addScaledVector(up,-(frame.top+frame.height/2-viewHeight/2)*unitsPerPixel);
    world.updateMatrixWorld(true);positionCamera();
  }
  function layoutContent() {
    fitFrame();
    bounds=projectedBounds();
    const left=bounds.left+1,top=bounds.top+1;
    const right=bounds.left+bounds.width-1,bottom=bounds.top+bounds.height-1;
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
    world.updateMatrixWorld(true);
    fold.render(state.effect);
    renderer.render(world,camera);
  }
  function resize() {
    viewWidth=container.clientWidth;viewHeight=container.clientHeight;
    renderer.setSize(viewWidth,viewHeight);
    camera.aspect=viewWidth/viewHeight;camera.updateProjectionMatrix();
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
    model.scale.setScalar(modelScale);model.position.set(0,0.04-0.00764*modelScale,-0.4+12.42971*modelScale);
    lid=model.getObjectByName('CladofoldLid');screen=model.getObjectByName('CladofoldScreen');
    if(!lid || !screen)throw new Error('The lid model is incomplete.');
    model.getObjectByName('Base').visible=false;
    model.traverse(object=>{if(object.isMesh && object.material?.metalness!==undefined)object.material.envMapIntensity=0.5;});
    screen.material=fold.material;world.add(model);world.updateMatrixWorld(true);
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
