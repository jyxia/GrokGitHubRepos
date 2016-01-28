//
//  GitHubAPIManager.swift NEW!!!
//  GrokGitHubAPI
//
//  Created by Christina Moulton on 2015-07-19.
//  Copyright (c) 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import Locksmith

class GitHubAPIManager
{
  static let sharedInstance = GitHubAPIManager()
  
  // replace your clientID and clientSecret here
  var clientID: String = "123456"
  var clientSecret: String = "0b0b0b0b0b0"
  
  var OAuthToken: String?
  {
    set
    {
      if let valueToSave = newValue
      {
        do
        {
          try Locksmith.saveData(["token": valueToSave], forUserAccount: "github")
        } catch _
        {
          do
          {
            try Locksmith.deleteDataForUserAccount("github")
          } catch _ {}
        }
      }
      else
      {
        do
        {
          try Locksmith.deleteDataForUserAccount("github")
        } catch _{}
        removeSessionHeaderIfExists("Authorization")
      }
    }
    get
    {
      // try to load from keychain
      let dictionary = Locksmith.loadDataForUserAccount("github")
      if let token =  dictionary?["token"] as? String {
        return token
      }
      removeSessionHeaderIfExists("Authorization")
      return nil
    }
  }
  
  func alamofireManager() -> Manager
  {
    let manager = Alamofire.Manager.sharedInstance
    addSessionHeader("Accept", value: "application/vnd.github.v3+json")
    return manager
  }
  
  func addSessionHeader(key: String, value: String)
  {
    let manager = Alamofire.Manager.sharedInstance
    if var sessionHeaders = manager.session.configuration.HTTPAdditionalHeaders as? Dictionary<String, String>
    {
      sessionHeaders[key] = value
      manager.session.configuration.HTTPAdditionalHeaders = sessionHeaders
    }
    else
    {
      manager.session.configuration.HTTPAdditionalHeaders = [
        key: value
      ]
    }
  }
  
  func removeSessionHeaderIfExists(key: String)
  {
    let manager = Alamofire.Manager.sharedInstance
    if var sessionHeaders = manager.session.configuration.HTTPAdditionalHeaders as? Dictionary<String, String>
    {
      sessionHeaders.removeValueForKey(key)
      manager.session.configuration.HTTPAdditionalHeaders = sessionHeaders
    }
  }
  
  // handlers for the oauth process
  // stored as vars since sometimes it requires a round trip to safari which
  // makes it hard to just keep a reference to it
  var oauthTokenCompletionHandler:(NSError? -> Void)?
  
  func hasOAuthToken() -> Bool
  {
    if let token = self.OAuthToken
    {
      return !token.isEmpty
    }
    return false
  }
  
  // MARK: - OAuth flow
  func startOAuth2Login()
  {
    //removeSessionHeaderIfExists("Authorization")
    let authPath:String = "https://github.com/login/oauth/authorize?client_id=\(clientID)&scope=repo&state=TEST_STATE"
    
    if let authURL:NSURL = NSURL(string: authPath)
    {
      let defaults = NSUserDefaults.standardUserDefaults()
      defaults.setBool(true, forKey: "loadingOauthToken")
      
      UIApplication.sharedApplication().openURL(authURL)
    }
  }
  
  func processOauthStep1Response(url: NSURL)
  {
    print(url)
    let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    var code:String?
    if let queryItems = components?.queryItems
    {
      for queryItem in queryItems
      {
        if (queryItem.name.lowercaseString == "code")
        {
          code = queryItem.value
          break
        }
      }
    }
    if let receivedCode = code {
      let getTokenPath:String = "https://github.com/login/oauth/access_token"
      let tokenParams = ["client_id": clientID, "client_secret": clientSecret, "code": receivedCode]
      // don't use sharedManager because we don't want to pass an old, invalid oauthToken if we have one
      Alamofire.request(.POST, getTokenPath, parameters: tokenParams)
        .responseString { response in
          if let anError = response.result.error
          {
            print(anError)
            if let completionHandler = self.oauthTokenCompletionHandler
            {
              let noAuthError = NSError(domain: "AlamofireErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not obtain an Oauth code", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
              let defaults = NSUserDefaults.standardUserDefaults()
              defaults.setBool(false, forKey: "loadingOauthToken")
              completionHandler(noAuthError)
            }
            return
          }
          if let receivedResults = response.result.value
          {
            let resultParams:Array<String> = receivedResults.characters.split{$0 == "&"}.map(String.init)
            for param in resultParams
            {
              let resultsSplit = param.characters.split{ $0 == "=" }.map(String.init)
              if (resultsSplit.count == 2)
              {
                let key = resultsSplit[0].lowercaseString // access_token, scope, token_type
                let value = resultsSplit[1]
                switch key {
                case "access_token":
                  self.OAuthToken = value
                  print("token value: \(value)")
                case "scope":
                  // TODO: verify scope
                  print("SET SCOPE")
                case "token_type":
                  // TODO: verify is bearer
                  print("CHECK IF BEARER")
                default:
                  print("got more than I expected from the oauth token exchange")
                }
              }
            }
          }
          
          let defaults = NSUserDefaults.standardUserDefaults()
          defaults.setBool(false, forKey: "loadingOauthToken")
          
          if self.hasOAuthToken()
          {
            if let completionHandler = self.oauthTokenCompletionHandler
            {
              completionHandler(nil)
            }
          }
          else
          {
            //self.removeSessionHeaderIfExists("Authorization")
            if let completionHandler = self.oauthTokenCompletionHandler
            {
              // TODO: create error "no token" with some way to handle it
              let noAuthError = NSError(domain: "AlamofireErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not obtain an Oauth token", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
              completionHandler(noAuthError)
            }
          }
      }
    }
    else
    {
      // no code in URL that we launched with
      let defaults = NSUserDefaults.standardUserDefaults()
      defaults.setBool(false, forKey: "loadingOauthToken")
    }
  }
q
}
