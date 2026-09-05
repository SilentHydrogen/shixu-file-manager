const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
const ts=require(process.env.ARKTS_TYPESCRIPT_PATH || path.join(process.env.DEVECO_CLI_CLT_PATH,'hvigor/hvigor-ohos-plugin/node_modules/typescript'));
require.extensions['.ets']=(m,f)=>m._compile(ts.transpileModule(fs.readFileSync(f,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,esModuleInterop:true,target:ts.ScriptTarget.ES2020}}).outputText,f);
const stores=new Map(),db=new Map(),app=new Map();let configured=false,consent=true,remoteCalls=0,scores=[],remoteDecision,mutateBeforeTool;
function pref(name){if(!stores.has(name)){const data=new Map();stores.set(name,{getSync:(k,d)=>data.has(k)?data.get(k):d,putSync:(k,v)=>data.set(k,v),deleteSync:k=>data.delete(k),flush:async()=>{}})}return stores.get(name)}
global.AppStorage={get:k=>app.get(k),setOrCreate:(k,v)=>app.set(k,v)};
class Repository{async findByUri(uri){return db.get(uri)||null}async insert(f){f.id=db.size+1;db.set(f.uri,f);return f.id}async findById(id){return [...db.values()].find(f=>f.id===id)||null}async updateCategory(id,category){const f=await this.findById(id);if(f)f.category=category}}
const rag={initialize:async()=>{},processFile:async id=>{const f=await new Repository().findById(id);f.isProcessed=true},localCategoryScores:async()=>scores,search:async()=>[]};
const llm={isConfigured:()=>configured,reinitialize(){},cancelClassification(){},async classifyFile(name,type,content,categories,examples,execute){remoteCalls++;if(mutateBeforeTool)mutateBeforeTool();await execute(remoteDecision)}};
const original=Module._load;Module._load=function(id,...args){
 if(id==='@ohos.data.preferences')return {getPreferencesSync:(_c,o)=>pref(o.name)};
 if(id==='@ohos.data.relationalStore')return {};
 if(id==='@ohos.batteryInfo')return {chargingStatus:2,BatteryChargeState:{ENABLE:1,FULL:3}};
 if(id.endsWith('/DatabaseManager'))return {DatabaseManager:{getInstance:()=>({init:async()=>{}})}};
 if(id.endsWith('/FileRepository'))return {FileRepository:Repository};
 if(id==='./RagAnalysisService')return {RagAnalysisService:{getInstance:()=>rag}};
 if(id.endsWith('/LLMService'))return {LLMService:{getInstance:()=>llm}};
 if(id.endsWith('/LLMConfig'))return {LLMConfigManager:{getInstance:()=>({load:async()=>{},getConfig:()=>({baseURL:'fixture',model:'model',protocol:'responses'})})}};
 if(id==='./PrivacyConsentManager')return {PrivacyConsentManager:{getInstance:()=>({load:async()=>{},canUpload:()=>consent})}};
 return original.call(this,id,...args);
};
const base='../entry/src/main/ets/';
const {FileOrganizeService}=require(base+'service/FileOrganizeService.ets');
const {ruleMatches,organizeByRules}=require(base+'service/ClassificationRules.ets');
const {OrganizeSettings,inOrganizeWindow}=require(base+'service/OrganizeSettings.ets');
const categories=[{name:'研究',color:'blue',icon:'R',subtitle:'实验记录'},{name:'生活',color:'green',icon:'L',subtitle:'日常事务'},{name:'待整理',color:'gray',icon:'?',subtitle:''}];
const file=(id=1)=>({id,uri:'fixture://'+id,name:'sample.txt',kind:'文本',extension:'txt',contentText:'实验温度记录',tag:'待整理',color:'gray',icon:'?',manualTag:false,organizedAt:0,importedAt:1});
const rule={id:1,name:'实验',titleKeywords:'',contentKeywords:'温度',formats:'txt',targetTag:'研究',enabled:true,isDefault:false};
function seed(files=[file()],rules=[]){stores.clear();db.clear();app.clear();configured=false;consent=true;scores=[];remoteCalls=0;mutateBeforeTool=null;const s=pref('file_box_data');s.putSync('files',JSON.stringify(files));s.putSync('rules',JSON.stringify(rules));s.putSync('categories',JSON.stringify(categories));}
async function service(){const s=new FileOrganizeService();await s.initialize({});return s}
(async()=>{
 assert.equal(ruleMatches(file(),rule),true,'content keywords participate in rules');
 assert.equal(ruleMatches({...file(),contentText:'无关内容'},rule),false);
 seed([file()],[rule]);let s=await service();let result=await s.organize();assert.equal(result.applied,1);assert.equal(s.files()[0].tag,'研究');assert.equal(s.files()[0].color,'blue');assert.equal(db.get('fixture://1').category,'研究');assert.equal(remoteCalls,0);
 seed();scores=[{category:'研究',score:0.81},{category:'生活',score:0.4}];s=await service();result=await s.organize();assert.equal(result.applied,1);assert.equal(remoteCalls,0);assert.equal(s.files()[0].manualTag,false);assert.equal(s.files()[0].aiCategory,'研究');assert.equal(organizeByRules(s.files()[0],[],categories,true).tag,'研究','rule refresh preserves AI category');
 seed();scores=[{category:'研究',score:0.81},{category:'生活',score:0.78}];s=await service();result=await s.organize();assert.equal(result.review,1);assert.equal(s.files()[0].tag,'待整理');s=await service();result=await s.organize();assert.equal(result.review,0,'durable completion prevents repeated suggestions');await s.acceptSuggestion(s.pendingReviews()[0].id);assert.equal(s.files()[0].manualTag,true);assert.equal(db.get('fixture://1').category,'研究');
 seed([file()],[rule,{...rule,id:2,targetTag:'生活'}]);configured=true;remoteDecision={category:'研究',confidence:0.99,insufficientContent:false,reason:'fixture'};s=await service();result=await s.organize();assert.equal(remoteCalls,1);assert.equal(result.review,1,'conflicting rules require review despite high model confidence');
 seed();configured=true;remoteDecision={category:'研究',confidence:0.95,insufficientContent:false,reason:'fixture'};s=await service();result=await s.organize();assert.equal(result.applied,1);assert.equal(s.files()[0].tag,'研究');
 seed();configured=true;remoteDecision={category:'不属于用户分类',confidence:1,insufficientContent:false,reason:'fixture'};s=await service();result=await s.organize();assert.equal(result.review,1);assert.equal(s.pendingReviews()[0].suggestedCategory,'待整理');
 seed([{...file(),manualTag:true,tag:'生活'}]);configured=true;s=await service();result=await s.organize(1);assert.equal(result.skipped,1);assert.equal(remoteCalls,0);assert.equal(s.files()[0].tag,'生活');
 seed();configured=true;remoteDecision={category:'研究',confidence:0.95,insufficientContent:false,reason:'fixture'};mutateBeforeTool=()=>pref('file_box_data').putSync('files',JSON.stringify([{...file(),tag:'生活',manualTag:true}]));s=await service();await assert.rejects(()=>s.organize(1),/变化/);assert.equal(s.files()[0].tag,'生活','in-flight model cannot overwrite a new manual decision');
 seed();configured=true;consent=false;scores=[{category:'研究',score:0.8},{category:'生活',score:0.4}];s=await service();await s.organize();assert.equal(remoteCalls,0,'no consent means local-only');
 seed();s=await service();result=await s.organize(undefined,()=>false);assert.equal(result.remaining,1);assert.equal(s.files()[0].tag,'待整理');
 // A manual request cancels a background model call before it can write, then takes over.
 seed([file(1),file(2)]);configured=true;remoteDecision={category:'研究',confidence:0.95,insufficientContent:false,reason:'fixture'};
 let release,entered;const gate=new Promise(resolve=>release=resolve),started=new Promise(resolve=>entered=resolve);
 const normalClassify=llm.classifyFile;let first=true;
 llm.classifyFile=async(...args)=>{if(first){first=false;entered();await gate;}return normalClassify.apply(llm,args)};
 llm.cancelClassification=()=>release();s=await service();const background=s.organize(undefined,()=>true,90000);await started;
 const manual=s.organize(2);const backgroundResult=await background;const manualResult=await manual;
 assert.equal(backgroundResult.applied,0);assert.equal(manualResult.applied,1);assert.equal(s.files()[0].tag,'待整理');assert.equal(s.files()[1].tag,'研究');
 llm.classifyFile=normalClassify;llm.cancelClassification=()=>{};
 let settings=new OrganizeSettings({});assert.equal(settings.allowed(true,12),true);assert.equal(settings.allowed(false,3),true);assert.equal(settings.allowed(false,12),false);await settings.save({enabled:true,charging:false,startHour:22,endHour:4});assert.equal(settings.allowed(true,12),false);assert.equal(settings.allowed(false,23),true);assert.equal(inOrganizeWindow(4,22,4),false);await settings.save({enabled:false,charging:true,startHour:2,endHour:4});assert.equal(settings.allowed(true,3),false);
 console.log('PASS: shared rule/manual/AI category writes, custom categories, local fallback, confidence and conflict review, durable jobs, stale-result protection, consent, charging OR normal/overnight windows');
})().catch(error=>{console.error(error);process.exitCode=1});
