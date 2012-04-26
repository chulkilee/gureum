//
//  GureumComposer.m
//  CharmIM
//
//  Created by youknowone on 11. 9. 16..
//  Copyright 2011 youknowone.org. All rights reserved.
//

#import "GureumComposer.h"

#import "CIMConfiguration.h"
#import "GureumAppDelegate.h"

NSString *kGureumInputSourceIdentifierQwerty = @"org.youknowone.inputmethod.GureumKIM.qwerty";
NSString *kGureumInputSourceIdentifierDvorak = @"org.youknowone.inputmethod.GureumKIM.dvorak";
NSString *kGureumInputSourceIdentifierDvorakQwertyCommand = @"org.youknowone.inputmethod.GureumKIM.dvorakq";
NSString *kGureumInputSourceIdentifierColemak = @"org.youknowone.inputmethod.GureumKIM.colemak";
NSString *kGureumInputSourceIdentifierColemakQwertyCommand = @"org.youknowone.inputmethod.GureumKIM.colemakq";
NSString *kGureumInputSourceIdentifierHan2 = @"org.youknowone.inputmethod.GureumKIM.han2";
NSString *kGureumInputSourceIdentifierHan2Classic = @"org.youknowone.inputmethod.GureumKIM.han2classic";
NSString *kGureumInputSourceIdentifierHan3Final = @"org.youknowone.inputmethod.GureumKIM.han3final";
NSString *kGureumInputSourceIdentifierHan390 = @"org.youknowone.inputmethod.GureumKIM.han390";
NSString *kGureumInputSourceIdentifierHan3NoShift = @"org.youknowone.inputmethod.GureumKIM.han3noshift";
NSString *kGureumInputSourceIdentifierHan3Classic = @"org.youknowone.inputmethod.GureumKIM.han3classic";
NSString *kGureumInputSourceIdentifierHan3Layout2 = @"org.youknowone.inputmethod.GureumKIM.han3layout2";
NSString *kGureumInputSourceIdentifierHanAhnmatae = @"org.youknowone.inputmethod.GureumKIM.han3ahnmatae";
NSString *kGureumInputSourceIdentifierHanRoman = @"org.youknowone.inputmethod.GureumKIM.hanroman";

#import "HangulComposer.h"

@implementation GureumComposer

- (id)init
{
    self = [super init];
    if (self) {
        self->romanComposer = [[CIMBaseComposer alloc] init];
        self->hangulComposer = [[HangulComposer alloc] init];
        self->hanjaComposer = [[HanjaComposer alloc] init];
        self->hanjaComposer.delegate = self->hangulComposer;
        self.delegate = self->romanComposer;
    }
    return self;
}

- (void)dealloc
{
    self.inputMode = nil;
    [self->romanComposer release];
    [self->hangulComposer release];
    [self->hanjaComposer release];
    [super dealloc];
}

NSDictionary *GureumInputSourceToHangulKeyboardIdentifierTable = nil;
+ (void)initialize {
    GureumInputSourceToHangulKeyboardIdentifierTable = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                        @"", kGureumInputSourceIdentifierQwerty,
                                                        @"2", kGureumInputSourceIdentifierHan2,
                                                        @"2y", kGureumInputSourceIdentifierHan2Classic,
                                                        @"3f", kGureumInputSourceIdentifierHan3Final,
                                                        @"39", kGureumInputSourceIdentifierHan390,
                                                        @"3s", kGureumInputSourceIdentifierHan3NoShift,
                                                        @"3y", kGureumInputSourceIdentifierHan3Classic,
                                                        @"32", kGureumInputSourceIdentifierHan3Layout2,
                                                        @"ro", kGureumInputSourceIdentifierHanRoman,
                                                        @"ahn", kGureumInputSourceIdentifierHanAhnmatae,
                                                        nil];
}

- (void)setInputMode:(NSString *)newInputMode {
    ICLog(TRUE, @"** GureumComposer -setLayoutIdentifier: from input mode %@ to %@", self.inputMode, newInputMode);
    if (self.inputMode == newInputMode || [self.inputMode isEqualToString:newInputMode]) return;
    
    NSString *keyboardIdentifier = [GureumInputSourceToHangulKeyboardIdentifierTable objectForKey:newInputMode];
    if ([keyboardIdentifier length] == 0) {
        self.delegate = self->romanComposer;
    } else {
        self.delegate = self->hangulComposer;
        // 단축키 지원을 위해 마지막 자판을 기억
        [self->hangulComposer setKeyboardWithIdentifier:keyboardIdentifier];
        CIMConfigurationSetObjectForField(CIMSharedConfiguration, newInputMode, lastHangulInputMode);
        [CIMSharedConfiguration saveConfigurationForStringField:&CIMSharedConfiguration->lastHangulInputMode];
    }
    
    [super setInputMode:newInputMode];
}


-(CIMInputTextProcessResult)inputController:(CIMInputController *)controller inputText:(NSString *)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    NSInteger inputModifier = flags & NSDeviceIndependentModifierFlagsMask & ~NSAlphaShiftKeyMask;
    // TODO: hardcoded shortcut handling -> input handler로 옮기자!
    if (inputModifier == CIMSharedConfiguration->inputModeExchangeKeyModifier && keyCode == CIMSharedConfiguration->inputModeExchangeKeyCode) {
        ICLog(TRUE, @"***** Keyboard Changed *****");
        // 한영전환을 위해 현재 입력 중인 문자 합성 취소
        [self.delegate cancelComposition];
        if (self.delegate == self->romanComposer) {
            NSString *lastHangulInputMode = CIMSharedConfiguration->lastHangulInputMode;
            if (lastHangulInputMode == nil) lastHangulInputMode = kGureumInputSourceIdentifierHan2;
            [sender selectInputMode:lastHangulInputMode];
        } else {
            [sender selectInputMode:kGureumInputSourceIdentifierQwerty];
        }
        return CIMInputTextProcessResultProcessed;
    }
    if (self.delegate == self->hanjaComposer) {
        if (!self->hanjaComposer.mode && self->hanjaComposer.composedString.length == 0 && self->hanjaComposer.commitString.length == 0) {
            // 한자 입력이 완료되었고 한자 모드도 아님
            self.delegate = self->hangulComposer;
        }
    }
    if (self.delegate == self->hangulComposer) {
        if (inputModifier == CIMSharedConfiguration->inputModeHanjaKeyModifier && keyCode == CIMSharedConfiguration->inputModeHanjaKeyCode) {
            // 현재 조합 중 여부에 따라 한자 모드 여부를 결정
            self->hanjaComposer.mode = self->hangulComposer.composedString.length == 0;
            self.delegate = self->hanjaComposer;
            [self.delegate composerSelected:self];
            return CIMInputTextProcessResultProcessed;
        }
    }
    // general composer
    CIMInputTextProcessResult result = [self.delegate inputController:controller inputText:string key:keyCode modifiers:flags client:sender];
    return result;
}

@end