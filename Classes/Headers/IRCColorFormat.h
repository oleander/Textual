/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TVCTextViewWithIRCFormatter.h" // superclass

typedef NS_ENUM(NSUInteger, IRCTextFormatterEffectType) {
	IRCTextFormatterBoldEffect,
	IRCTextFormatterItalicEffect,
	IRCTextFormatterStrikethroughEffect,
	IRCTextFormatterUnderlineEffect,
	IRCTextFormatterForegroundColorEffect,
	IRCTextFormatterBackgroundColorEffect,
};

TEXTUAL_EXTERN NSString * const IRCTextFormatterBoldAttributeName; // BOOL
TEXTUAL_EXTERN NSString * const IRCTextFormatterItalicAttributeName; // BOOL
TEXTUAL_EXTERN NSString * const IRCTextFormatterStrikethroughAttributeName; // BOOL
TEXTUAL_EXTERN NSString * const IRCTextFormatterUnderlineAttributeName; // BOOL
TEXTUAL_EXTERN NSString * const IRCTextFormatterForegroundColorAttributeName; // NSNumber, 0-15
TEXTUAL_EXTERN NSString * const IRCTextFormatterBackgroundColorAttributeName; // NSNumber, 0-15

#define IRCTextFormatterColorEffectCharacter			0x03
#define IRCTextFormatterBoldEffectCharacter				0x02
#define IRCTextFormatterItalicEffectCharacter			0x1d
#define IRCTextFormatterItalicEffectCharacterOld		0x16
#define IRCTextFormatterStrikethroughEffectCharacter	0x1e
#define IRCTextFormatterUnderlineEffectCharacter		0x1F
#define IRCTextFormatterTerminatingCharacter			0x0F

#define IRCTextFormatterMaximumRainbowTextFormattingLength   300

@interface NSAttributedString (IRCTextFormatter)
/* Returns an NSString with appropriate formatting characters. */
@property (readonly, copy) NSString *attributedStringToASCIIFormatting;

/* Given contextual information (client, channel, lineType), the original attributed
 string is converted to use appropriate formatting characters, but this method does
 not allow the result to exceed TXMaximumIRCBodyLength. If the result exceeds this
 length, then it returns the remaining buffer in textToFormat for later processing. */
/* The only valid lineType value is PRIVMSG, ACTION, or NOTICE. Any other will proxy
 to the -attributedStringToASCIIFormatting method defined above. */
+ (NSString *)attributedStringToASCIIFormatting:(NSMutableAttributedString **)textToFormatt
									 withClient:(IRCClient *)client
										channel:(IRCChannel *)channel
									   lineType:(TVCLogLineType)lineType;

- (BOOL)IRCFormatterAttributeSetInRange:(IRCTextFormatterEffectType)effect
                                  range:(NSRange)limitRange;
@end

@interface NSMutableAttributedString (IRCTextFormatter)
- (void)setIRCFormatterAttribute:(IRCTextFormatterEffectType)effect 
                           value:(id)value 
                           range:(NSRange)limitRange;

- (void)removeIRCFormatterAttribute:(IRCTextFormatterEffectType)effect 
                              range:(NSRange)limitRange;
@end
