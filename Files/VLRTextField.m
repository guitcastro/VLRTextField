//
//  VLRTextField.m
//  VeryLastRoom
//
//  Created by Marian Paul on 18/03/14.
//  Copyright (c) 2014 RezZza. All rights reserved.
//

#import "VLRTextField.h"
#import "VLRFormService.h"
#import "VLRMultiDelegates.h"
#import "VLRTextFieldMacros.h"

#import "NSString+VLRTextField.h"

#import <PPHelpMe/PPHelpMe.h>

#define FLOATING_ERROR_MESSAGE_VIEW_ANIMATION_Y 5

@interface VLRTextField ()
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) VLRMultiDelegates *delegates;
@end

@implementation VLRTextField

#pragma mark - Object Life

- (void)commonVLRInit
{
    self.fillRequired                        = YES;
    self.messageRequired                     = @"Please enter some text";
    self.minimumNumberOfCharacters           = 0;
    self.shouldCheckWhileEditing             = NO;
    self.shouldCleanSpacesBeforeRegex        = NO;
    self.shouldTrimWhitespacesBeforeRegex    = YES;
    self.floatingLabelActiveValidTextColor   = [UIColor blueColor];
    self.floatingLabelActiveUnvalidTextColor = [UIColor redColor];
    self.applyTextOffsetOnEditing            = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vlrTextFieldDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    
    self.delegates = [VLRMultiDelegates new];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonVLRInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonVLRInit];
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonVLRInit];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Checking methods

- (BOOL)isContentValidWithRegex:(NSString*)regex
{
    NSParameterAssert(regex);
    NSError *regexError = nil;
    
    NSString *textToCheck = self.text;
    if (self.shouldCleanSpacesBeforeRegex) {
        textToCheck = [textToCheck vlrTextField_cleanSpaces];
    }
    
    NSRegularExpression *regexExpression = [NSRegularExpression regularExpressionWithPattern:regex
                                                                                     options:NSRegularExpressionCaseInsensitive
                                                                                       error:&regexError];
    NSUInteger numberOfMatchesForRegex = [regexExpression numberOfMatchesInString:textToCheck
                                                                          options:0
                                                                            range:NSMakeRange(0, [textToCheck length])];
    
    BOOL textValid = numberOfMatchesForRegex != 0;
    return textValid;
}

- (BOOL)isContentValid:(NSError *__autoreleasing *)error
{
    if (![self canBecomeFirstResponder]) {
        // We assume it's content is valid
        VLRTextFieldLog(@"The text field (%@) can not became first responder. Assuming it's content is valid", self.text);
        return YES;
    }
    
    // Before anything, just trim characters
    if (self.shouldTrimWhitespacesBeforeRegex) {
        self.text = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    
    // First, check if filled and required
    if (self.fillRequired) {
        BOOL filled = [self.text length] != 0;
        if (self.minimumNumberOfCharacters != 0) {
            filled &= [self.text length] >= self.minimumNumberOfCharacters;
        }
        
        if (!filled) {
            if (error) {
                *error = [NSError errorWithDomain:VLRTextFieldErrorDomain
                                             code:VLRTextFieldNotFilled
                                         userInfo:@{NSLocalizedDescriptionKey: self.messageRequired}];
            }
            
            return NO;
        }
    }
    
    // If we are here, then this is filled. We just have to check if valid, if required
    if (self.messageInvalid) {
        if (self.regex) {
            BOOL textValid = [self isContentValidWithRegex:self.regex];
            
            if (!textValid) {
                if (error) {
                    *error = [NSError errorWithDomain:VLRTextFieldErrorDomain
                                                 code:VLRTextFieldNotValid
                                             userInfo:@{NSLocalizedDescriptionKey: self.messageInvalid}];
                }
                
                return NO;
            }
        }
        if (self.validateBlock) {
            BOOL valid = self.validateBlock(self);
            
            if (!valid) {
                if (error) {
                    *error = [NSError errorWithDomain:VLRTextFieldErrorDomain
                                                 code:VLRTextFieldNotValid
                                             userInfo:@{NSLocalizedDescriptionKey: self.messageInvalid}];
                }
                
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark - Error Handling

- (void)addErrorViewFromError:(NSError *)error {
    if (self.errorLabel) return;
    
    self.floatingLabel.hidden = true;
    
    UILabel *errorMessageView = [UILabel newWithFrame:CGRectMake(0.0f,
                                                                 self.floatingLabelYPadding + FLOATING_ERROR_MESSAGE_VIEW_ANIMATION_Y,
                                                                 CGRectGetWidth(self.frame),
                                                                 CGRectGetHeight(self.floatingLabel.frame))];
    errorMessageView.backgroundColor = self.superview.backgroundColor ? : self.backgroundColor;
    errorMessageView.text            = error.localizedDescription;
    errorMessageView.textColor       = self.floatingLabelActiveUnvalidTextColor;
    errorMessageView.font            = self.floatingLabel.font;
    errorMessageView.textAlignment   = self.textAlignment;
    errorMessageView.alpha           = 0.0;
    
    [self addSubview:errorMessageView];
    self.errorLabel = errorMessageView;
}

- (void)animateErrorViewApparition {
    [UIView animateWithDuration:0.1
                     animations:
     ^{
         if (self.errorLabel.alpha != 1.0f) {
             self.errorLabel.alpha = 1.0f;
             [self.errorLabel setOrigin:CGPointMake(CGRectGetMinX(self.errorLabel.frame), CGRectGetMinY(self.errorLabel.frame))];
         }
     }];
}

- (void)removeErrorView {
    if (self.errorLabel) {

        self.floatingLabel.hidden = false;
    
        UILabel *errorLabel = self.errorLabel;
        self.errorLabel = nil;
        
        [UIView animateWithDuration:0.3
                         animations:
         ^{
             errorLabel.alpha = 0.0f;
             [errorLabel setOrigin:CGPointMake(CGRectGetMinX(errorLabel.frame), CGRectGetMinY(errorLabel.frame) + FLOATING_ERROR_MESSAGE_VIEW_ANIMATION_Y)];
         }
                         completion:
         ^(BOOL finished) {
             [errorLabel removeFromSuperview];
         }];
    }
}

- (void)handleTextChange
{
    [self removeErrorView];
    if (self.shouldCheckWhileEditing)
    {
        BOOL isValid = [self isContentValid:nil];
        if (isValid) {
            self.floatingLabelActiveTextColor = self.floatingLabelActiveValidTextColor;
        } else {
            self.floatingLabelActiveTextColor = self.floatingLabelActiveUnvalidTextColor;
        }
    }
}

- (void)setText:(NSString *)text
{
    BOOL textChanged = [text isEqualToString:self.text] ? NO : YES;
    [super setText:text];
    
    if (!self.userInteractionEnabled) {
        [self.floatingLabel removeFromSuperview];
    }
    
    if (textChanged) {
        [self handleTextChange];
    }
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
    [super setUserInteractionEnabled:userInteractionEnabled];
    
    if (!userInteractionEnabled) {
        [self.floatingLabel removeFromSuperview];
    }
}

#pragma mark - Notification Management

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.errorLabel setFrame:CGRectMake(0.0f, self.floatingLabelYPadding, CGRectGetWidth(self.frame), CGRectGetHeight(self.floatingLabel.frame))];
}

- (void)vlrTextFieldDidChange:(NSNotification *)notification {
    VLRTextField *textField = [notification object];
    if ([textField isEqual:self]) {
        [self handleTextChange];
    }
}

- (void)setDelegate:(id<UITextFieldDelegate>)delegate {
    [self.delegates addDelegate:delegate];
    [super setDelegate:(id<UITextFieldDelegate>)self.delegates];
}

#pragma mark - Overriding

- (CGRect)applyOffsetOnTextRectIfNeeded:(CGRect)rect {
    if (self.applyTextOffsetOnEditing && (self.userInteractionEnabled && [self.text length])) {
        CGFloat topInset = ceilf(self.floatingLabel.font.lineHeight + self.placeholderYPadding);
        topInset = MIN(topInset, [self maxTopInset]);
        rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(topInset, 0.0f, 0.0f, 0.0f));
    }
    return rect;
}

- (CGRect)applyOffsetOnEditingTextRectIfNeeded:(CGRect)rect {
    if (self.applyTextOffsetOnEditing && (self.userInteractionEnabled && [self.text length])) {
        CGFloat topInset = ceilf(self.floatingLabel.font.lineHeight + self.placeholderYPadding);
        topInset = MIN(topInset, [self maxTopInset]);
        rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(topInset, 0.0f, 0.0f, 0.0f));
    }
    return rect;
}

- (CGFloat)maxTopInset {
    return MAX(0, floorf(self.bounds.size.height - self.font.lineHeight - 4.0f));
}

@end

NSString * const VLRTextFieldErrorDomain = @"VLRTextFieldErrorDomain";
