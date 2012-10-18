SimpleXmlArchiver - Objective-C object graph archiving and unarchiving made easy!

# Introduction

Instead of having to implement coding/decoding methods for every property on every object by hand, simply use the simple XML archiver to convert your object graph(s) to XML and archive that instead.

Check the project wiki on GitHub for usage and the latest info: https://github.com/NLxAROSA/SimpleXmlArchiver/wiki

# Getting started

1. Download the source code and open it up in Xcode;
2. Run the program in the iOS iPhone simulator;
3. Outputs to console and label in UI;
4. Profit!

The interesting class here is SimpleArchiver. It has two methods:

`+(NSString *)objectToXml:(id)objectToEncode;`

This method takes any object tree and serializes it to an autoreleased XML String.

# Usage:

`NSString *result = [SimpleArchiver objectToXml:myObjectRef];`

Archive the resulting NSString using NSKeyedArchiver (only one key necessary! :))

`+(id)xmlToObject:(NSString *)xmlString targetClass:(Class)targetClass;`

This method takes the generated XML String and deserializes it back to an instance of the specifed targetClass.

Unarchive the NSString from your archive using NSKeyedUnarchiver, then pass it to the SimpleArchiver like so: `MyObject *myObjectRef = [SimpleArchiver xmlToObject:result targetClass:[MyObject class]];`


# Usage in your own project

1. Add the following to 'Header Search Paths' (Debug is enough): /usr/include/libxml2
2. Add the following to 'Other Linker Flags' (Debug is enough): -lxml2
3. Add the Constants, SimpleArchiver and GDataXMLNode classes to your project