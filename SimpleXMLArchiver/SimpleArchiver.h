//
//  SimpleArchiver.h
//  SimpleXMLArchiver
//
//  Copyright (c) 2012 Lars Rosenquist. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0

//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

@interface SimpleArchiver : NSObject

//
//  Converts an object graph to an XML String
//
+(NSString *)objectToXml:(id)objectToEncode;

//
//  Converts an XML String back to an object graph, using the specified target
//  class as an entry point
//
+(id)xmlToObject:(NSString *)xmlString targetClass:(Class)targetClass;

@end
