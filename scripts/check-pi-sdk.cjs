// Exercise the real bundled Pi SDK and the Harmony HTTP adapter with provider fixtures.
const assert = require('node:assert/strict');
const path = require('node:path');
const Module = require('node:module');
const esbuild = require(process.env.ESBUILD_PATH || 'esbuild');
const nativeProcess = process;
const NativeEncoder = global.TextEncoder, NativeDecoder = global.TextDecoder;
const NativeURL = global.URL, NativeURLSearchParams = global.URLSearchParams;
let fixture, requests = [], destroyed = 0;
const encode = text => new NativeEncoder().encode(text).buffer;
const load = Module._load;
Module._load = function(id, ...args) {
  if (id === '@ohos.buffer') return {Blob: require('node:buffer').Blob};
  if (id === '@ohos.net.http') return {HttpDataType:{ARRAY_BUFFER:2}, createHttp:() => ({
    async request(url, options) { requests.push({url,body:JSON.parse(options.extraData)}); return {
      responseCode: fixture.status || 200, result: encode(fixture.body), header: {'content-type': fixture.type || 'text/event-stream'}
    }; }, destroy(){destroyed++}
  })};
  if (id === '@ohos.util') return {TextEncoder:class {encodeInto(s){return new NativeEncoder().encode(s)}},
    TextDecoder:{create:label => ({decodeToString:(bytes,options)=>new NativeDecoder(label).decode(bytes,options)})}};
  if (id === '@ohos.url') return {URL:NativeURL, URLSearchParams:NativeURLSearchParams};
  return load.call(this,id,...args);
};
function responses(text, toolArgs) {
  const item = toolArgs ? {type:'function_call',id:'fc_1',call_id:'call_1',name:'classify_file',arguments:JSON.stringify(toolArgs)}
    : {type:'message',id:'msg_1',role:'assistant',content:[{type:'output_text',text}]};
  return [
    {type:'response.created',response:{id:'resp_1',status:'in_progress'}},
    {type:'response.output_item.added',output_index:0,item:{...item,arguments:toolArgs?'':undefined,content:toolArgs?undefined:[]}},
    ...(toolArgs ? [{type:'response.function_call_arguments.delta',delta:JSON.stringify(toolArgs)}] : [
      {type:'response.content_part.added',part:{type:'output_text',text:''}},
      {type:'response.output_text.delta',delta:text}
    ]),
    {type:'response.output_item.done',item,output_index:0},
    {type:'response.completed',response:{id:'resp_1',status:'completed',output:[item],usage:{input_tokens:3,output_tokens:2,total_tokens:5}}}
  ].map(event=>`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`).join('');
}
(async()=>{
 const outfile='/tmp/shixu-pi-sdk-test.cjs';
 await esbuild.build({entryPoints:[path.resolve('packages/pi-agent-harmony/index.js')],outfile,bundle:true,platform:'node',format:'cjs',external:['@ohos.*','node:*'],logLevel:'silent'});
 // Match Harmony: these browser globals are absent before loading the package.
 for (const name of ['TextEncoder','TextDecoder','fetch','Headers','Request','Response','ReadableStream','AbortController','AbortSignal','URL','URLSearchParams','structuredClone','Buffer','crypto','FormData','File','Blob','navigator']) delete global[name];
 delete global.process;
 const {runAgent}=require(outfile);
 const config={apiKey:'fixture-key-never-persisted',baseURL:'https://fixture.example/v1/responses/',model:'fixture',protocol:'auto',maxTokens:1000,temperature:0};
 const request={messages:[{role:'user',content:'请回答'}]};
 fixture={body:responses('连接成功：中文流式回答')};
 const reply=JSON.parse(await runAgent(JSON.stringify(config),JSON.stringify(request),'test-responses'));
 assert.equal(reply.content,'连接成功：中文流式回答');assert.equal(reply.tokens,5);
 assert.equal(requests[0].url,'https://fixture.example/v1/responses');assert.equal(requests[0].body.stream,true);assert.ok(requests[0].body.input);
 fixture={body:'data: '+JSON.stringify({id:'chat_1',model:'fixture',choices:[{index:0,delta:{role:'assistant',content:'普通对话'},finish_reason:null}]})+'\n\ndata: '+JSON.stringify({choices:[{index:0,delta:{},finish_reason:'stop'}]})+'\n\ndata: [DONE]\n\n'};
 const chat=JSON.parse(await runAgent(JSON.stringify({...config,baseURL:'https://fixture.example/v1',protocol:'chat_completions'}),JSON.stringify(request),'test-chat'));
 assert.equal(chat.content,'普通对话');assert.equal(requests.at(-1).url,'https://fixture.example/v1/chat/completions');
 fixture={body:responses('',{category:'工作',confidence:0.92,reason:'会议文件',insufficientContent:false})};
 let calls=0;const before=requests.length;
 await runAgent(JSON.stringify(config),JSON.stringify({...request,categories:['工作','待整理']}),'test-tool',async raw=>{calls++;assert.equal(JSON.parse(raw).category,'工作');return JSON.stringify({status:'applied'})});
 assert.equal(calls,1);assert.equal(requests.length-before,1,'tool result terminates the SDK loop');
 fixture={body:responses('',{category:'不存在',confidence:0.99,reason:'invalid',insufficientContent:false})};
 calls=0;
 await assert.rejects(()=>runAgent(JSON.stringify(config),JSON.stringify({...request,categories:['工作','待整理']}),'test-invalid-tool',async()=>{calls++;return '{}'}));
 assert.equal(calls,0,'SDK validates category enum before application');
 fixture={status:401,type:'application/json',body:JSON.stringify({error:{message:config.apiKey}})};
 await assert.rejects(()=>runAgent(JSON.stringify(config),JSON.stringify(request),'test-auth'),error=>/401/.test(error.message)&&!error.message.includes(config.apiKey));
 fixture={body:'<html>fixture-key-never-persisted</html>',type:'text/html'};
 await assert.rejects(()=>runAgent(JSON.stringify(config),JSON.stringify(request),'test-invalid'),error=>!error.message.includes(config.apiKey));
 assert.ok(destroyed>=requests.length);
 global.process = nativeProcess;
 console.log('PASS: real Pi SDK Responses SSE, Chat Completions SSE, Chinese text, tool loop, enum validation, safe errors and HTTP cleanup');
})().catch(error=>{global.process=nativeProcess;console.error(error);nativeProcess.exitCode=1});
