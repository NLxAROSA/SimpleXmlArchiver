//
//  SimpleArchiver.m
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

#import "SimpleArchiver.h"
#import "Constants.h"
#import "GDataXMLNode.h"
#import "objc/runtime.h"

@implementation SimpleArchiver

//
//  Encodes an object graph to an XML String
//
+(NSString *)objectToXml:(id)objectToEncode  {
    
    const char *objectName = class_getName([objectToEncode class]);
	NSString *objectNameStr = [NSString stringWithUTF8String:objectName];
    
    GDataXMLElement *rootElement = nil;
    GDataXMLNode *attribute = nil;
    
    if ([objectToEncode isKindOfClass:[NSArray class]]) {
        rootElement = [GDataXMLElement elementWithName:MUTABLE_ARRAY_TYPE];
        attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:MUTABLE_ARRAY_TYPE];
        [rootElement addAttribute:attribute];
        [SimpleArchiver encodeArray:objectToEncode element:rootElement];
    }else{
        rootElement = [GDataXMLElement elementWithName:objectNameStr];
        attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:objectNameStr];
        [rootElement addAttribute:attribute];
        [SimpleArchiver encodeElement:objectToEncode parentElement:rootElement];
    }
    
    GDataXMLDocument *doc = [[GDataXMLDocument alloc]initWithRootElement:rootElement];
    NSString *result = [[[NSString alloc]initWithData:[doc XMLData] encoding:NSUTF8StringEncoding] autorelease];
    [doc release];
    return result;
}

//
// Encodes an object and its properties into a GDataXMLElement
//
+(void)encodeElement:(id)objectToEncode parentElement:(GDataXMLElement *)parentElement    {
    
    // Retrieve all properties for the given object
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList([objectToEncode class], &propertyCount);
    
    for (int i = 0; i < propertyCount; i++) {
        
        objc_property_t property = properties[i];
        
        // Get the property name
        const char *propName = property_getName(property);
        // Convert into NSString to insert into XML
        NSString *propertyNameStr = [NSString stringWithUTF8String:propName];
        GDataXMLElement *element = [GDataXMLElement elementWithName:propertyNameStr];
        
        // Convert property name into selector
        SEL selector = sel_registerName(propName);

        // Execute the selector to get the property, and store it in the XML tree (deep)
        [self getPropertyValue:selector target:objectToEncode intoElement:element];
        [parentElement addChild:element];

    }
}

//
// Encodes an array of objects and their properties into a GDataXMLElement
//
+(void)encodeArray:(id)returnId element:(GDataXMLElement *)intoElement  {
    NSArray* ar = (NSArray*) returnId;
    NSEnumerator *en = [ar objectEnumerator];
    id arrayObject = nil;
    GDataXMLNode *attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:MUTABLE_ARRAY_TYPE];
    [intoElement addAttribute:attribute];
    NSString *classNameStr = nil;
    while (arrayObject = [en nextObject])    {
        
        const char* className = class_getName([arrayObject class]);
        classNameStr = [NSString stringWithUTF8String:className];
        
        GDataXMLElement *element = [GDataXMLElement elementWithName:classNameStr];
        [self encodeElement:arrayObject parentElement:element];
        GDataXMLNode *attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:classNameStr];
        [element addAttribute:attribute];
        [intoElement addChild:element];
    }
    GDataXMLNode *attribute2 = [GDataXMLNode attributeWithName:ATTRIBUTE_ENCLOSING_TYPE stringValue:classNameStr];
    [intoElement addAttribute:attribute2];
}

//
// Extracts a property value using the objc_runtime and puts it into a GDataXMLElement
// Extend this if you want to add extra property types
//
+(void)getPropertyValue:(SEL)selector target:(id)target intoElement:(GDataXMLElement *)intoElement  {
    
    // Get the return type
    Method getterMethod = class_getInstanceMethod([target class], selector);
    char returnType[ 256 ];
    method_getReturnType(getterMethod, returnType, 256 );
    
    NSMethodSignature* methodSignature = [[target class]
                                          instanceMethodSignatureForSelector:selector];
    NSInvocation* invocation = [NSInvocation
                                  invocationWithMethodSignature:methodSignature];
    [invocation setSelector:selector];
    [invocation invokeWithTarget:target];

    // Add XML node based on type of property
    switch (returnType[0]) {
            
        case '@':   {
            // Return type is object type
            id returnId;
            [invocation getReturnValue:&returnId];
            
            // NSxxxx classes first
            if ([returnId isKindOfClass:[NSString class]])   {
                NSString* str = (NSString *)returnId;
                [intoElement setStringValue:str];
                GDataXMLNode *attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:STRING_TYPE];
                [intoElement addAttribute:attribute];
            }else if ([returnId isKindOfClass:[NSNumber class]]){
                NSNumber *num = (NSNumber *) returnId;
                [intoElement setStringValue:[num stringValue]];
                GDataXMLNode *attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:NUMBER_TYPE];
                [intoElement addAttribute:attribute];
            }else if ([returnId isKindOfClass:[NSArray class]]){
                [self encodeArray:returnId element:intoElement];
            }else{
                // Some other (custom) object, inspect this deeper, be sure to add any native Obj-C types
                // (like NSxxxx) before this one
                [self encodeElement:returnId parentElement:intoElement];
                if (returnId)  {
                    const char *objectName = class_getName([returnId class]);
                    NSString *objectNameStr = [NSString stringWithUTF8String:objectName];
                    GDataXMLNode *attribute = [GDataXMLNode attributeWithName:ATTRIBUTE_TYPE stringValue:objectNameStr];
                    [intoElement addAttribute:attribute];
                }
            }
        }
            
            break;
            
            // Primitive types follow after this
        case 'c':   {
            // char, BOOL, etc.
            char returnValue;
            
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%i", returnValue]];
        }
            break;
        case 'i':   {
            // int
            int returnValue;
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%i", returnValue]];
        }
            break;
        case 's':   {
            // short
            short returnValue;
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%hd", returnValue]];
        }
            break;
        case 'l':   {
            // long
            long returnValue;
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%li", returnValue]];
        }
            break;
        case 'f':   {
            // float
            float returnValue;
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%f", returnValue]];
        }
            break;
        case 'd':   {
            // double
            double returnValue;
            [invocation getReturnValue:&returnValue];
            [intoElement setStringValue:[NSString stringWithFormat:@"%f", returnValue]];
        }
            break;
        default:
            break;
    }
}

//
//  Converts an XML String back to an object graph, using the specified target
//  class as an entry point
//
+(id)xmlToObject:(NSString *)xmlString targetClass:(Class)targetClass  {
    
    NSError *error = [[NSError alloc]init];
    GDataXMLDocument *doc = [[GDataXMLDocument alloc]initWithXMLString:xmlString options:0 error:&error];
    GDataXMLElement *rootElement = [doc rootElement];
    NSMutableString* xpath = [NSMutableString stringWithString:XPATH_START];
    [xpath appendString:rootElement.name];
    id result = nil;
    
    if ([targetClass isSubclassOfClass:[NSArray class]])    {
        result = [self parseArray:rootElement];
    }else{
        const char* className = class_getName(targetClass);
        NSString* classNameStr = [NSString stringWithUTF8String:className];
        
        result = [self parseElement:rootElement targetClass:targetClass rootPath:classNameStr index:0];
    }
    
    [doc release];
    return result;
}

//
//  Parses the specified GDataXMLElement back into an object structure using the specified target class and XPath
//
+(id)parseElement:(GDataXMLElement *)element targetClass:(Class)targetClass rootPath:(NSString *)rootPath index:(int)index{
    
    id newObject = [[[targetClass alloc]init] autorelease];
    
    // Inspect object for its properties
    unsigned int outCount = 0;
    objc_property_t *properties = class_copyPropertyList(targetClass, &outCount);
    
    for (int i = 0; i < outCount; i++) {
        
        objc_property_t property = properties[i];
        
        // Get the property name
        const char *propName = property_getName(property);
        // Convert into NSString to insert into XML
        NSString *propertyNameStr = [NSString stringWithUTF8String:propName];
        
        NSMutableString *propertyXpath = [NSMutableString stringWithString:XPATH_START];
        
        [propertyXpath appendString:rootPath];
        [propertyXpath appendString:XPATH_NODE_SEPARATOR];
        [propertyXpath appendString:propertyNameStr];
        
        [self setPropertyValue:propertyNameStr target:newObject forElement:element xPath:propertyXpath index:index];
        
    }
    
    return newObject;
}

//
// Parses an array back into its object structure
//
+(NSMutableArray *)parseArray:(GDataXMLElement *)element    {
    
    // Array type, parse elements of array
    GDataXMLNode *enclosingTypeAttribute = [element attributeForName:ATTRIBUTE_ENCLOSING_TYPE];
    NSString* enclosingTypeString = [enclosingTypeAttribute stringValue];
    NSError *error = [[NSError alloc]init];
    NSMutableString *xpath = [NSMutableString stringWithString:XPATH_START];
    [xpath appendString:enclosingTypeString];
    NSArray *childNodes = [element nodesForXPath:xpath error:&error];
    
    NSMutableArray* ar = [[[NSMutableArray alloc]initWithCapacity:[childNodes count]]autorelease];
    NSEnumerator *en = [childNodes objectEnumerator];
    
    GDataXMLElement* ce = nil;
    int i=0;
    
    while (ce = [en nextObject])    {
        [ar insertObject:[self parseElement:ce targetClass:NSClassFromString(ce.name) rootPath:enclosingTypeString index:i] atIndex:[ar count]];
        i++;
    }
    
    
    return ar;
}

//
//  Sets a property value on a given object using the specified GDataXMLElement and Xpath
//  Extend this if you wish to add extra property types
//  Note: this still misses some property types as well as implementations
//
+(void)setPropertyValue:(NSString *)propertyName target:(id)target forElement:(GDataXMLElement *)element xPath:(NSMutableString *)xPath index:(int)index    {
    
    NSString *firstChar = [[propertyName substringToIndex:1]uppercaseString];
    NSString *remainingChar = [propertyName substringFromIndex:1];
    NSMutableString *setterString = [NSMutableString stringWithString:@"set"];
    [setterString appendString:firstChar];
    [setterString appendString:remainingChar];
    [setterString appendString:@":"];
    
    // Convert property name into selector
    SEL getter = sel_registerName([propertyName cStringUsingEncoding:NSUTF8StringEncoding]);
    
    SEL setter = sel_registerName([setterString UTF8String]);

    // Get the return type
    Method m = class_getInstanceMethod([target class], getter);
    char ret[256];
    method_getReturnType(m, ret, 256 );
        
    NSMethodSignature* getterSignature = [[target class] instanceMethodSignatureForSelector:getter];
    NSInvocation* getterInvocation = [NSInvocation invocationWithMethodSignature:getterSignature];
    [getterInvocation setSelector:getter];
    [getterInvocation invokeWithTarget:target];
    
    NSMethodSignature* setterSignature = [[target class] instanceMethodSignatureForSelector:setter];
    NSInvocation* setterInvocation = [NSInvocation invocationWithMethodSignature:setterSignature];
    [setterInvocation setSelector:setter];
    
    switch (ret[0]) {
            
        case '@':   {

            NSError *error = [[NSError alloc]init];
            NSArray *nodes = [element nodesForXPath:xPath error:&error];
            GDataXMLElement *childElement = (GDataXMLElement *)[nodes objectAtIndex:index];
            GDataXMLNode *attribute = [childElement attributeForName:ATTRIBUTE_TYPE];

            NSString* classNameString = [attribute stringValue];
            Class clazz = NSClassFromString(classNameString);
            
            if (clazz == [NSString class])   {

                NSString* str = childElement.stringValue;
                [target performSelector:setter withObject:str];
                
            }else if (clazz == [NSNumber class]){
                
                NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
                [f setNumberStyle:NSNumberFormatterDecimalStyle];
                NSNumber* num = [f numberFromString:childElement.stringValue];
                [f release];
                
                [target performSelector:setter withObject:num];
            }else if (clazz == [NSMutableArray class]){
                NSMutableArray* ar = [self parseArray:childElement];
                [target performSelector:setter withObject:ar];
            }else{
                // Some other object, parse XML further
                if (attribute != nil)   {
                    NSString* classNameString = [attribute stringValue];
                    Class cls = NSClassFromString(classNameString);
                    
                    id child = [self parseElement:(GDataXMLElement*)childElement targetClass:cls rootPath:propertyName index:0];
                    
                    [target performSelector:setter withObject:child];
                    
                }
                
            }
        }
            
            break;
        case 'c':   {
            
            NSError *error = [[NSError alloc]init];
            NSArray *nodes = [element nodesForXPath:xPath error:&error];
            GDataXMLNode *node = [nodes objectAtIndex:index];
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber* num = [f numberFromString:node.stringValue];
            [f release];
            char charValue = [num charValue];
            
            [setterInvocation setArgument:&charValue atIndex:2];
            [setterInvocation invokeWithTarget:target];
        }
            break;
        case 'i':   {
            NSError *error = [[NSError alloc]init];
            NSArray *nodes = [element nodesForXPath:xPath error:&error];
            GDataXMLNode *node = [nodes objectAtIndex:index];
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber* num = [f numberFromString:node.stringValue];
            [f release];
            int intValue = [num intValue];
            
            [setterInvocation setArgument:&intValue atIndex:2];
            [setterInvocation invokeWithTarget:target];
        }
            break;
        case 's':   {
        }
            break;
        case 'l':   {
        }
            break;
        case 'f':   {
            NSError *error = [[NSError alloc]init];
            NSArray *nodes = [element nodesForXPath:xPath error:&error];
            GDataXMLNode *node = [nodes objectAtIndex:index];
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            [f setDecimalSeparator:@"."];
            
            NSNumber* num = [f numberFromString:node.stringValue];
            [f release];
            float floatValue = [num floatValue];
            
            [setterInvocation setArgument:&floatValue atIndex:2];
            [setterInvocation invokeWithTarget:target];

        }
            break;
        case 'd':   {
            NSError *error = [[NSError alloc]init];
            NSArray *nodes = [element nodesForXPath:xPath error:&error];
            GDataXMLNode *node = [nodes objectAtIndex:index];
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber* num = [f numberFromString:node.stringValue];
            [f release];
            double doubleValue = [num doubleValue];
            
            [setterInvocation setArgument:&doubleValue atIndex:2];
            [setterInvocation invokeWithTarget:target];
        }
            break;
        default:
            break;
    }
}

@end
