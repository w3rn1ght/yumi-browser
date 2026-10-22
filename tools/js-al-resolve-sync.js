(function(){
  try{
    var payload=JSON.parse('{"url":"a2eaa868-41e2-486d-81f0-c2f124f82803","episode":1,"shikimoriId":10335,"translation":"AniLibria"}');
    var x=new XMLHttpRequest();
    x.open('POST','/api/aniliberty/resolve',false);
    x.setRequestHeader('Content-Type','application/json');
    x.setRequestHeader('Accept','*/*');
    x.send(JSON.stringify(payload));
    return JSON.stringify({status:x.status,text:(x.responseText||'').slice(0,160)});
  }catch(e){return JSON.stringify({status:0,text:String(e)});}
})()
