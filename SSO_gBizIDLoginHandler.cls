/**
 * gBizID との SSO を行うための Registration Handler
 * 認証プロバイダの登録ハンドラーに設定して使用
 * https://developer.salesforce.com/docs/atlas.ja-jp.apexcode.meta/apexcode/apex_auth_plugin.htm
 * ---- ---- ---- ----
 * 2020/11/03 @Hiroyuki Inaba
 */
public class SSO_gBizIDLoginHandler implements Auth.RegistrationHandler {

// User オブジェクトの定型的属性情報
  private static final String COUNTRY = 'JP';
  private static final String TIME_ZONE = 'Asia/Tokyo';
  private static final String LANGUAGE = 'ja';
  private static final String LOCALE = 'ja_JP';
  private static final String EMAIL_ENCODE = 'UTF-8';

  class RegHandlerException extends Exception {}

/**
 * @description      : 初回 SSO 時に呼び出されるメソッド。gBizID 側のアカウントと Lightning Platform のユーザのマッピングが行われる
 * @param portalId   : 認証プロバイダのポータルに設定されたポータルの値
 * @param data       : UserInfo で渡されてくる情報
 * @return User      : 紐付けを作成するユーザレコード
 **/
  public User createUser(Id portalId, Auth.UserData data){

    //渡されてきたデータに電子メールアドレスが含まれていない場合はエラーを返す
    if(String.isBlank(data.attributeMap.get('user_email'))) throw new RegHandlerException('Cannot find attribute user_email from UserInfo Attributes.');

    //統合 ID の項目値でユーザレコードを検索し、存在する場合は渡されてきたその他属性値をユーザレコードに設定する
    List<User> userList = [SELECT Id FROM User WHERE FederationIdentifier = :data.attributeMap.get('user_email')];
    if(userList.size() == 1) {
      userList[0] = updateUserAttributes(userList[0], data);
      update userList[0];
    }else{
      // ユーザレコードが存在しない、もしくは 1 以外の場合にはエラーを返す
      throw new RegHandlerException('Cannot find User record with identifier provided from User Object. Or found duplicated user records.');
    }

    return userList[0];
  }

/**
 * @description      : 2 回目以降のログイン時に呼びだされるメソッド
 * @param userId     : 紐付けられたユーザレコードの ID
 * @param portalId   : 認証プロバイダのポータルに設定されたポータルの値
 * @param data       : UserInfo で渡されてくる情報
 **/
  public void updateUser(Id userId, Id portalId, Auth.UserData data){

    //ユーザレコードのオブジェクト ID でユーザレコードを検索し、存在する場合は渡されてきたその他属性値をユーザレコードに設定する
    List<User> userList = [SELECT Id FROM User WHERE Id = :userId AND IsActive = true];
    if(userList.size() == 1) {
      User u = updateUserAttributes(userList[0], data);
      update u;
    }else{
      // ユーザレコードが存在しない、もしくは 1 以外の場合にはエラーを返す
      throw new RegHandlerException('Cannot find User record with identifier provided from User Object. Or found duplicated user records.');
    }
  }


/**
 * @description  : 内部的に使用するユーザレコードへの情報格納処理
 * @param u      : ユーザレコード
 * @param data   : UserInfo で渡されてきた情報
 * @return User  : 項目の値更新後のユーザレコード
 **/
  private static User updateUserAttributes(User u, Auth.UserData data) {

    // gBizID 固有データ
    u.gbiz_sub__c = data.identifier;
    u.gbiz_parent_id__c = data.attributeMap.get('parent_id');
    u.gbiz_account_type__c = data.attributeMap.get('account_type');
    u.gbiz_corp_type__c = data.attributeMap.get('corp_type');
    u.gbiz_corporate_number__c = data.attributeMap.get('corporate_number');
    u.gbiz_mandate_info__c = data.attributeMap.get('mandate_info');

    // ユーザデータ
    u.LastName  = data.attributeMap.get('user_last_nm');
    u.FirstName  = data.attributeMap.get('user_first_nm');
    u.Email = data.attributeMap.get('user_email');
    u.Phone = data.attributeMap.get('user_tel_no_contact');
    u.Department = data.attributeMap.get('user_department');
    u.CompanyName = data.attributeMap.get('name');
    String alias = data.attributeMap.get('user_email');
    if(alias.length() > 8) alias = alias.substring(0,8);
    u.Alias = alias;

    // 住所データ
    u.Country = COUNTRY;
    u.PostalCode = data.attributeMap.get('user_post_code');
    u.City = data.attributeMap.get('user_address1');
    u.Street = data.attributeMap.get('user_address2') + ' ' + data.attributeMap.get('user_address3');
    u.State = data.attributeMap.get('user_prefecture_name');

    // (都道府県はコードが渡されてくるので都道府県名とのマッピングテーブルをカスタムメタデータとして作成し使用)
    String code = data.attributeMap.get('user_prefecture_name');
    List<StateListJisX0401__mdt> states = [SELECT MasterLabel, Code__c FROM StateListJisX0401__mdt WHERE Code__c =:code];
    if(states.size() == 1) u.State = states[0].MasterLabel;

    // その他属性データ
    u.TimeZoneSidKey    = TIME_ZONE;
    u.LanguageLocaleKey = LANGUAGE;
    u.LocaleSidKey      = LOCALE;
    u.EmailEncodingKey  = EMAIL_ENCODE;

    return u;
  }
}
