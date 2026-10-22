(function(){
  function get(u){try{var x=new XMLHttpRequest();x.open('GET',u,false);x.send(null);return {status:x.status,text:x.responseText||''};}catch(e){return {status:0,text:String(e)};}}
  var id="10335";
  var a=get('/api/sources?shikimoriId='+id);
  var k=get('/api/akuro/sources?shikimoriId='+id);
  return JSON.stringify({id:id, aStatus:a.status, aLen:a.text.length, kStatus:k.status, kLen:k.text.length});
})()
