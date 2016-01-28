//
//  Repo.swift
//  GrokGitHubAPI
//
//  Created by Christina Moulton on 2015-07-17.
//  Copyright (c) 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import Locksmith

class Repo {
  var id: String?
  var name: String?
  var description: String?
  var ownerLogin: String?
  var url: String?
  
  required init?(response: NSHTTPURLResponse, representation: AnyObject) {
    self.name = representation.valueForKeyPath("name") as? String
  }
  
  required init(json: JSON) {
    self.description = json["description"].string
    self.id = json["id"].string
    self.name = json["name"].string
    self.ownerLogin = json["owner"]["login"].string
    self.url = json["url"].string
  }
  
  class func getMyRepos(completionHandler: (Array<Repo>?, NSError?) -> Void)
  {
    let path = "https://api.github.com/user/repos"
    let URL = NSURL(string: path)!
    let mutableURLRequest = NSMutableURLRequest(URL: URL)
    mutableURLRequest.HTTPMethod = Alamofire.Method.GET.rawValue
    if let token =  GitHubAPIManager.sharedInstance.OAuthToken {
      // this is a preferred way to set token in HTTP request, see https://github.com/Alamofire/Alamofire#modifying-session-configuration
      mutableURLRequest.setValue( "token \(token)", forHTTPHeaderField: "Authorization")
    }
    
    GitHubAPIManager.sharedInstance.alamofireManager().request(mutableURLRequest)
      .validate()
      .responseRepoArray { response in
        if let anError = response.result.error
        {
          print("get Repos error: \(anError)")
          // TODO: parse out errors more specifically
          // for now, let's just wipe out the oauth token so they'll get forced to redo it
          //GitHubAPIManager.sharedInstance.OAuthToken = nil
          completionHandler(nil, response.result.error)
          return
        }
        completionHandler(response.result.value, nil)
    }
  }
}

extension Alamofire.Request {
  func responseRepoArray(completionHandler: Response<[Repo], NSError> -> Void) -> Self {
    
    let responseSerializer = ResponseSerializer<Array<Repo>, NSError> { request, response, data, error in
      guard error == nil else {
        return .Failure(error!)
      }
      guard let responseData = data else {
        let failureReason = "Array could not be serialized because input data was nil."
        let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
        return .Failure(error)
      }
      
      let JSONResponseSerializer = Request.JSONResponseSerializer(options: .AllowFragments)
      let result = JSONResponseSerializer.serializeResponse(request, response, responseData, error)
      
      switch result {
      case .Success(let value):
        let json = SwiftyJSON.JSON(value)
        var repos:Array = Array<Repo>()
        for (_, jsonRepo) in json
        {
          let repo = Repo(json: jsonRepo)
          repos.append(repo)
        }
        return .Success(repos)
      case .Failure(let error):
        return .Failure(error)
      }
      
    }
    
    return response(responseSerializer: responseSerializer, completionHandler: completionHandler)
  }
}
