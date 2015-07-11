//
//  WebLinking.swift
//  WebLinking
//
//  Created by Kyle Fuller on 20/01/2015.
//  Copyright (c) 2015 Cocode. All rights reserved.
//

import Foundation

/// A structure representing a RFC 5988 link.
public struct Link: Equatable, Hashable {
  public let uri:String
  public let parameters:[String:String]

  public init(uri:String, parameters:[String:String] = [:]) {
    self.uri = uri
    self.parameters = parameters
  }

  public var hashValue:Int {
    return uri.hashValue
  }

  /// Relation type of the Link.
  public var relationType:String? {
    return parameters["rel"]
  }

  /// Reverse relation of the Link.
  public var reverseRelationType:String? {
    return parameters["rev"]
  }

  /// A hint of what the content type for the link may be.
  public var type:String? {
    return parameters["type"]
  }
}

public func ==(lhs:Link, rhs:Link) -> Bool {
  return lhs.uri == rhs.uri && lhs.parameters == rhs.parameters
}

// MARK: HTML Element Conversion

/// An extension to Link to provide conversion to a HTML element
extension Link {
  /// Encode the link into a HTML element
  public var html:String {
    let components = map(parameters) { (key, value) in
      "\(key)=\"\(value)\""
      } + ["href=\"\(uri)\""]
    let elements = join(" ", components)
    return "<link \(elements) />"
  }
}

// MARK: Header link conversion

/// An extension to Link to provide conversion to a "Link" header
extension Link {
  /// Encode the link into a header
  public var header:String {
    let components = ["<\(uri)>"] + map(parameters) { (key, value) in
      "\(key)=\"\(value)\""
    }
    return join("; ", components)
  }

  public init(header:String) {
    let (uri, parametersString) = takeFirst(separateBy(";")(input: header))
    let parameters = parametersString.map(split("=")).map { parameter in
      [parameter.0: trim("\"", "\"")(input: parameter.1)]
    }

    self.uri = trim("<", ">")(input: uri)
    self.parameters = reduce(parameters, [:], +)
  }
}

/*** Parses a Web Linking (RFC5988) header into an array of Links
:param: header RFC5988 link header. For example `<?page=3>; rel=\"next\", <?page=1>; rel=\"prev\"`
:return: An array of Links
*/
public func parseLinkHeader(header:String) -> [Link] {
  return separateBy(",")(input: header).map { string in
    return Link(header: string)
  }
}

/// An extension to NSHTTPURLResponse adding a links property
extension NSHTTPURLResponse {
  /// Parses the links on the response `Link` header
  public var links:[Link] {
    if let linkHeader = allHeaderFields["Link"] as? String {
      return parseLinkHeader(linkHeader).map { link in
        var uri = link.uri

        /// Handle relative URIs
        if let baseURL = self.URL {
          if let URL = NSURL(string: uri, relativeToURL: baseURL) {
            if let uriString = URL.absoluteString {
              uri = uriString
            }
          }
        }

        return Link(uri: uri, parameters: link.parameters)
      }
    }

    return []
  }

  /// Finds a link which has matching parameters
  public func findLink(parameters:[String:String]) -> Link? {
    for link in links {
      if link.parameters ~= parameters {
        return link
      }
    }

    return nil
  }

  /// Find a link for the relation
  public func findLink(# relation:String) -> Link? {
    return findLink(["rel": relation])
  }
}

/// MARK: Private methods (used by link header conversion)

// Merge two dictionaries together
func +<K,V>(lhs:Dictionary<K,V>, rhs:Dictionary<K,V>) -> Dictionary<K,V> {
  var dictionary = [K:V]()

  for (key, value) in rhs {
    dictionary[key] = value
  }

  for (key, value) in lhs {
    dictionary[key] = value
  }

  return dictionary
}

/// LHS contains all the keys and values from RHS
func ~=(lhs:[String:String], rhs:[String:String]) -> Bool {
  for (key, value) in rhs {
    if lhs[key] != value {
      return false
    }
  }

  return true
}

// Separate a trim a string by a separator
func separateBy(separator:String)(input:String) -> [String] {
  return input.componentsSeparatedByString(separator).map {
    $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
  }
}

// Split a string by a separator into two components
func split(separator:String)(input:String) -> (String, String) {
  let range = input.rangeOfString(separator, options: NSStringCompareOptions(0), range: nil, locale: nil)

  if let range = range {
    let lhs = input.substringToIndex(range.startIndex)
    let rhs = input.substringFromIndex(range.endIndex)
    return (lhs, rhs)
  }

  return (input, "")
}

// Separate the first element in an array from the rest
func takeFirst(input:[String]) -> (String, ArraySlice<String>) {
  if let first = input.first {
    let items = input[input.startIndex.successor() ..< input.endIndex]
    return (first, items)
  }

  return ("", [])
}

// Trim a prefix and suffix from a string
func trim(lhs:Character, rhs:Character)(input:String) -> String {
  if input.hasPrefix("\(lhs)") && input.hasSuffix("\(rhs)") {
    return input[input.startIndex.successor()..<input.endIndex.predecessor()]
  }

  return input
}
