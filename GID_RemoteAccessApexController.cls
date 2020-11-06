/*
 * gBizID から委任情報を取得する処理を行う
 * ---- ---- ---- ----
 * 2020/11/3 @Hiroyuki Inaba
 */
public with sharing class GID_RemoteAccessApexController {

  // カスタムメタデータから設定値を取得する際の検索値
  private static final string DEVELOPERNAME  = 'gBizIDServiceAccount';

  /**
   * @description      : 委任情報を取得する API を呼び出し、委任された事業体の情報を受け取る
   * @return string    : status (success / error) と message (エラーの場合のメッセージ) もしくは body (受け取った委任情報の JSON)
   **/
  @AuraEnabled
  public static string getDelegation(){
    Map<String,Object> retvals = new Map<String,Object>();
    String meti_id = '';

    // ユーザオブジェクトのレコードからアカウント管理番号を取得。ユーザがない場合や管理番号が空の場合はエラーとして終了
    List<User> users = [SELECT gbiz_sub__c FROM User WHERE Id=:UserInfo.getUserId()];
    if(users.size() > 0) {
      meti_id = users[0].gbiz_sub__c;
    }else{
      retvals.put('status', 'error');
      retvals.put('message', 'no user record');
      return System.JSON.serialize(retvals);
    }

    if(String.isBlank(meti_id)) {
      retvals.put('status', 'error');
      retvals.put('message', 'no user record with valid sub.');
      return System.JSON.serialize(retvals);
    }

    // アクセスに必要な値をカスタムメタデータから取得し、リクエストボディを組み立て
    gBizIDServiceAccount__mdt meta = [SELECT ClientKey__c, ClientToken__c FROM gBizIDServiceAccount__mdt WHERE DeveloperName=:DEVELOPERNAME LIMIT 1];
    Map<String, String> m = new Map<String, String> {
      'client_key' => meta.ClientKey__c,
      'client_token' => meta.ClientToken__c,
      'meti_id' => meti_id
    };

    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    // API の URL は指定ログイン情報の設定を取得
    req.setEndpoint('callout:gbizid_delegation_request');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(m));

    try{
      HttpResponse res = new Http().send(req);
      if(res.getStatusCode() == 200) {

        // 内容のチェックを Apex 側で行う場合、JSON を分解して値にアクセスできるようにする
        Map<String,Object> objDelegation = (Map<String,Object>) System.JSON.deserializeUntyped(res.getBody());
        List<Object> arrayDelegations = (List<Object>) objDelegation.get('delegation_info');
        if(arrayDelegations.size() > 0) {
          for(Integer i = 0; i < arrayDelegations.size(); i++) {
            Map<String,Object> objCompanyInfo = (Map<String,Object>) arrayDelegations[i];

            // 今回はログに出力するだけだが、何らかのチェック処理を入れても良いだろう
            System.debug(objCompanyInfo.get('system_cd'));
            System.debug(objCompanyInfo.get('delegation_start'));
            System.debug(objCompanyInfo.get('delegation_end'));
          }
        }

        retvals.put('status', 'success');
        retvals.put('body', objDelegation);
        return System.JSON.serialize(retvals);
      }else{
        retvals.put('status', 'error');
        retvals.put('message', 'http request status: ' + res.getStatusCode() + ' ' + res.getStatus());
        return System.JSON.serialize(retvals);
      }
    }catch(Exception e) {
      retvals.put('status', 'error');
      retvals.put('message', e.getMessage());
      return System.JSON.serialize(retvals);
    }
  }
}