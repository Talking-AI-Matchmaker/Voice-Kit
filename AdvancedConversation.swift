//
//  AdvancedConversation.swift
//  AdvancedConversation
//
//  Created by Kevin Teman on 6/16/20.
//  Copyright © 2020 AIMM. All rights reserved.
//

import Foundation
import Overall
import Enobus
import SpeechInterpretation
import SpeechService
import Questions
import DialogOperation
import Conscious

public class AdvancedConversation: AdvancedConversationInterface {
        
        public lazy var main = Keeper.conversation as! InterconversationInterface & ConversationInterface
        public lazy var interpretation = Keeper.interpretation as! SpeechInterpretation
        public lazy var speechService = Keeper.speechService as! SpeechService
        
        public init() {
                self.installAdvancedReactions()
        }
        
        public var constantReactions:[Reaction] = []
        public var dialogIdentifiersLeadingToReactions = TriggersToReactions <Identifier> ()
        public var actionsLeadingToReactions = TriggersToReactions <Action> ()
        public var absenceOfActionsLeadingToReactions = TriggersToReactions <Action> ()
        
        private var actionType:UserInquiryType = .custom
        
        public var canIAskAQuestionVocabulary:Set<String> {
                get {
                        return Interpretation.CanIAskAQuestion.enobus.anticpatedWords
                }
        }
        
        lazy var viewInterface = self.main.viewInterface
        lazy var questions = self.main.questions
        lazy var defaultQuestions = Keeper.questions as! DefaultQuestions
        lazy var conscious = Keeper.conscious as! Conscious
        
        
        
        
        /**
         Called from outside to check for user inquiry.
         */
        public func checkForInquiry(wordsCollection:[String], finalInterpretation:Bool) -> UserInquiry? {
                
                
                /// By default, return custom type. (this can be changed when creating individual action handlers)
                
                self.actionType = .custom
                
                
                /// Execute reaction with words spoken to determine if action is necessary.
                
                func actionHandler(fromReaction reaction:Reaction) -> ActionHandler? {
                        
                        let action = reaction(wordsCollection, finalInterpretation)
                        
                        if action.0 {
                                return action.1
                        }
                        
                        return nil
                }
                
                
                /// Check for reactions possible from current and previous dialog spoken.
                
                var identifiers:[Identifier] {
                        var identifiers:[Identifier] = []
                        
                        if let identifier = self.speechService.lastDialogSpoken?.dialog.identifier {
                                identifiers.append(identifier)
                        }
                        
                        if let identifier = self.speechService.previousToLastDialogSpoken?.dialog.identifier {
                                identifiers.append(identifier)
                        }
                        
                        return identifiers
                }
                
                for identifier in identifiers {
                        
                        guard let reactions = self.dialogIdentifiersLeadingToReactions[identifier] else {
                                continue
                        }
                        
                        for reaction in reactions {
                                guard let handler = actionHandler(fromReaction: reaction) else {
                                        continue
                                }
                                
                                return UserInquiry(type: self.actionType, handler: handler)
                        }
                }
                
                
                /// Get instance-wide actions.
                
                let newestToOldest = Overseer.currentActions.reversed()
                
                let currentActions = Set (newestToOldest)
                
                
                
                /// Check for reactions possible from instance-wide actions.
                
                for action in newestToOldest {
                        
                        if let reactions = self.actionsLeadingToReactions[action] {
                                
                                for reaction in reactions {
                                        guard let handler = actionHandler(fromReaction: reaction) else {
                                                continue
                                        }
                                        
                                        return UserInquiry(type: self.actionType, handler: handler)
                                }
                        }
                }
                
                
                /// Check for reactions possible from instance-wide lack of actions.
                
                for (action, reactions) in self.absenceOfActionsLeadingToReactions.values where !currentActions.contains(action) {
                        
                        for reaction in reactions {
                                guard let handler = actionHandler(fromReaction: reaction) else {
                                        continue
                                }
                                
                                return UserInquiry(type: self.actionType, handler: handler)
                        }
                }
                
                
                
                /// Check for reactions possible at all times.
                
                for reaction in self.constantReactions {
                        guard let handler = actionHandler(fromReaction: reaction) else {
                                continue
                        }
                        
                        return UserInquiry(type: self.actionType, handler: handler)
                }
                
                
                
                return nil
        }
        
        public struct Interpretation {
                
                
                // MARK: - Previous Static Inquiries Which Have Become Dynamic
                
                public struct CanIAskAQuestion {
                        static let enobus = Enobus(withString: "I-have-a-question question questions")
                        static let advancedEnobus = Enobus(withString: "[have/got/I've1 question2] [ask something/question] [question1 you2] [quick1 question2] [need help/assistance] 2[hey1 aimm/aim/aimee/aimey/aime2] [see/show/display1 menu/options2] 3[I1 am2 question(s)3]")
                        static let dirtyFinal = Enobus(withString: "question [I/I'm/I've/I-have/a/the question(s)]", requiresFinal: true, ratioRequired: 1.0)
                }
                
                public static let helloString = "hello/hi/greeting(s)"
                
                public static let hello = Enobus(withString: helloString, requiresFinal: true, ratioRequired: 1.0)
                public static let imReady = Enobus(withString: "[I/I-am/I'm ready] [can-we/let's/let-us/ready go(ing)/start(ed)/play(ing)/continue]", ratioRequired: 1.0)
                public static let wakeUp = Enobus(withString: "wake-up", ratioRequired: 1.0)
                public static let beforeThat = Enobus(withString: "3[line/word/phrase/thing1 before/earlier2 that/line/word/phrase3] 2[before/earlier that] 2[last one/thing/line/phrase] 3[what1 one/thing/line/phrase2 said/before/before-that3]", ratioRequired: 1.0)
                
                public static let areYouOk = Enobus(withString: "3[are1 you2 ok/alright/all-right3]", ratioRequired: 1.0)
                public static let howAreYou = Enobus(withString: "3[how1 are2 you3] 3[are1 you2 well3]", ratioRequired: 1.0)
                public static let imThinking = Enobus(withString: "think/thinking [figure/figuring1 out2] [try/I'm/I-am think(ing)]", requiresFinal: true)
                public static let requestPictureStory = Enobus(withString: "3[want/do/try/ask-me/show1 picture2 story/selection3]")
                
                public static let speedUpRequest = Enobus(withString: "[talk/talking/voice/speak faster/quicker/pastor] 3[speed1 up2 voice3] 3[can/would/please1 speed2 up3]")
                public static let slowDownRequest = Enobus(withString: "[talk/talking/voice/speak slower] 3[slow1 down2 voice3] 3[can/would/please1 slow2 down3]")
                
                public static let whatAreYouDoing = Enobus(withString: "[what1 doing/up-to/up-two2]", ratioRequired: 1.0)
                public static let areYouAwake = Enobus(withString: "[you1 awake/alive2]", ratioRequired: 1.0)
                public static let areYouThere = Enobus(withString: "[are1 there/here2]", ratioRequired: 1.0)
                public static let areYouReady = Enobus(withString: "[are/you/get1 ready2]", ratioRequired: 1.0)
                
                public static let preWords = "ok/yes/fine/yeah/right/please"
                public static let goOn = Enobus(withString: "3[\(preWords) go on] [go1 on2]", ratioRequired: 1.0)
                public static let requestMoveOn = Enobus(withString: "[continue please] [keep1 going2] [move1 on2] 2[keep1 going2] [please1 move2] moveon/move-on/mullah/mulan/typic", addEnobii:[SpeechInterpretation.SkipIt.enobus, SpeechInterpretation.SkipItExtensive.enobus])
                public static let requestMoveOnFinal = SpeechInterpretation.SkipItExtensive.enobusFinalOnly
                public static let requestMoveOnExactFinal = Enobus(withString: /* small phrases like 'kik' better heard while speaking  */ "kick/kik/ticket/debit [give1 it2] [s/get this/that/us]", addEnobii: [SpeechInterpretation.SkipItExtensive.enobus], requiresFinal: true, ratioRequired: 1.0)
                
                public static let imFinished = Enobus(withString: "3[ok I'm/I-am finish(ed)/done] [I'm/I-am finish(ed)/done]", ratioRequired: 1.0)
                public static let nevermind = Enobus(withString: "[ok never-mind/nevermind] never-mind/nevermind", ratioRequired: 1.0)
                public static let iGetIt = Enobus(withString: "3[\(preWords)1 get/got2 it3] 3[I1 get/got2 it3] 3[\(preWords)1 I2 understand3] [I1 understand2] 3[\(preWords)1 that's/that-is/quite/totally2 enough3] [that's/that-is/quite/totally1 enough2] 3[\(preWords) enough that(s)/that-is] [enough that(s)/that-is] 3[\(preWords)1 sick/skip/done2 this/that/joke(s)/humor3] [sick/skip/done1 this/that/joke(s)/humor2] 3[\(preWords)1 I2 understand3] [I1 understand2]", ratioRequired: 0.7)
                
                public static let thatsAGreatQuestion = Enobus(withString: "4[this/question(s)1 is/are2 too3 \(Synonyms.goodOrGreat)4] 3[this/that/that's/you/that-is/this-is1 \(Synonyms.goodOrGreat)2 question3] 3[\(Synonyms.very)1 \(Synonyms.goodOrGreat)2 question3]", ratioRequired: 0.75)
                public static let thatsAGreatQuestionFinal = Enobus(withString: "[\(Synonyms.goodOrGreat) question(s)]", requiresFinal: true)
                public static let thatsNotAGreatQuestion = Enobus(withString: "3[not \(Synonyms.goodOrGreat) question(s)] 5[this/question(s)1 is/are2 not3 too4 \(Synonyms.goodOrGreat)5]")
                
                
                
                
                // MARK: - New Inquiries
                
                static let youreFunny = Enobus(withString: "[you/you're/you-are funny] 3[you/you're1 so2 funny3] [very/so1 funny/humor(ous)2]", requiresFinal: false)
                static let meToo = Enobus(withString: "[me/I-am1 too/as-well2]", requiresFinal: false, ratioRequired: 1.0)
                static let hi = Enobus(withString: helloString, requiresFinal: false, ratioRequired: 1.0)
                
                static let tooBright = Enobus(withString: "3[it's/that's/that-is1 too2 bright/white3] [too1 bright/white2] [can't/cannot see] 3[I1 can't/cannot2 see3] 4[I1 can't/cannot2 see3 anything/you4] [I'm/I-am1 blind2] 3[now I'm/I-am blind] 2[hurt(s)1 my-eye(s)/eye(s)2] 3[that/this/it1 hurt(s)2 my-eye(s)/eye(s)3]", requiresFinal: false, ratioRequired: 1.0)
                static let ouch = Enobus(withString: "ouch", requiresFinal: false, ratioRequired: 1.0)
                static let why = Enobus(withString: "why", requiresFinal: true, ratioRequired: 1.0)
                static let whyDoYouNeedToSeeMyFace = Enobus(withString: "3[why1 see2 face3] [why1 need2]", requiresFinal: false)
        }
        
        private func recognize(_ reaction: @escaping Reaction, during actions:Set<Action> = [], notDuring notWhileActions:Set<Action> = [], whileSpeaking identifiers:Set<Identifier> = []) {
                
                guard !actions.isEmpty || !notWhileActions.isEmpty || !identifiers.isEmpty else {
                        self.constantReactions.append(reaction)
                        return
                }
                
                for identifier in identifiers {
                        
                        self.dialogIdentifiersLeadingToReactions.add(reaction, toTrigger: identifier)
                }
                
                for action in actions {
                        
                        self.actionsLeadingToReactions.add(reaction, toTrigger: action)
                }
                
                for action in notWhileActions {
                        
                        self.absenceOfActionsLeadingToReactions.add(reaction, toTrigger: action)
                }
        }
        
        
        /**
         
         ADVANCED REACTIONS.
         
         Advanced reactions entail custom defined actions to interpretations that were erected and dismantled at key times (thus achieving maximum efficiency in running as little interpretation as possible). Interpretation is expensive. For example if the instance is performing action such as 'brightening the light for user' we can listen for specific phrases that are related to that action, respond accordingly, then continue in a desired way once finished. This is advanced conversation flow, or redirection of conversation. Think of a train switching tracks for a while then coming back to the same track at the same place or a further place down the line.
         
         */
        func installAdvancedReactions() {
                
                
                // MARK: - Helper functions
                
                /**
                 Get Reaction from set of enobii, optional action type, and optional pre-conditions which must be met before expensive interpretation takes place.
                 */
                func interpretation(_ enobii:[Enobus], not exlusionEnobii:[Enobus] = [], type:UserInquiryType = .custom, preCondition:((_ words:[String], _ final:Bool)->(Bool))? = nil, response actionHandler: @escaping ActionHandler) -> Reaction {
                        
                        let reaction:Reaction = { (wordsCollection, finalInterpretation) -> (WillTakeAction, ActionHandler?) in
                                
                                let preConditionPasses = preCondition == nil || preCondition!(wordsCollection, finalInterpretation)
                                
                                if preConditionPasses && self.match(fromWords: wordsCollection, final: finalInterpretation, enobii: enobii) && !self.match(fromWords: wordsCollection, final: finalInterpretation, enobii: exlusionEnobii) {
                                        
                                        self.actionType = type
                                        
                                        return ( WillTakeAction(true), actionHandler )
                                }
                                
                                return ( WillTakeAction(false), nil )
                        }
                        
                        return reaction
                }
                
                func interpretation(fromWords words:[String], final:Bool, enobii:[Enobus]) -> Enobus? {
                        
                        return enobii.first(where: { self.match(fromWords: words, final: final, enobus: $0) })
                }
                
                func previousInquiryMatchesOneOf(_ inquiries:Set<UserInquiryType>) -> Bool {
                        
                        guard let last = self.main.lastUserInquiry.value?.type else {
                                return false
                        }
                        
                        return inquiries.contains(last)
                }
                
                
                
                
                
                
                
                // MARK: - Begin Installation.........................
                
                
                
                
                
                
                // MARK: Screen is too bright, let's help the user.
                
                self.recognize ( interpretation( [Interpretation.tooBright, Interpretation.ouch] ) { resume in
                        
                        Keeper.brightness.fadeToPreviousBrightness(.fast)
                        
                        self.main.speakDialogs([.sorry]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, during: [.makingWhiteLightToMakeFaceVisible, .brighteningLightToMakeFaceVisible])
                
                
                
                
                
                
               
                
                
                
                
                
                
                // MARK: Respond with positive compliment back.
                
                self.recognize ( interpretation( [Interpretation.meToo] ) { resume in
                
                        self.main.speakDialogs([.happyToHearThat]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, whileSpeaking: [.welcomeBackLetsGetStarted, .welcomeBackLetsGetStarted, .youreAccountHasBeenEnabledShallWeStart, .goodLuckMyFriendImHappyToBeWorkingWithYou, .imGladYoureEnjoyingTheExperience, .imFine, .imResting, .justHangingOut, .imSoGladYoureAFemale, .nowThatThatsDoneImGoingToBed, .imExtremelyExcited, .imExcitedToContinueWorkingWithYou, .imGoingBackToBedHowInconsiderate, .thenYouMustHaveWokeUpEarlyToTalkToMe, .yesImHere, .imHere, .imAwake, .youMightThinkItsObviousButImASillyComputer, .ahImSoCute])
                
                
                
                
                
                
                // MARK: Respond With Thank You
                
                self.recognize ( interpretation( [Interpretation.youreFunny] ) { resume in
                        
                        self.main.speakDialogs([.thankYou]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, whileSpeaking: [.ohMyGoshImFunnyThoseAreAllTheSamePhone])
                
                
                
                
                // MARK: Respond to a Compliment
                
                self.recognize ( interpretation( [Interpretation.thatsAGreatQuestion, Interpretation.thatsAGreatQuestionFinal] , not: [Interpretation.thatsNotAGreatQuestion] ) { resume in
                        
                        self.main.speakDialogs([.thankYou]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, during: [.askProfileQuestion])
                
                
                
                
                
                
                
                
                
                
                
                // MARK: Respond to Hi from User.
                
                self.recognize ( interpretation( [Interpretation.hi] ) { resume in
                        
                        self.main.speakDialogs([.niceToSeeYou]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, whileSpeaking: [.hello, .welcomeBack, .wellHelloThere, .welcomeBackLetsGetStarted])
                
                
                
                
                
                
                
                
                
                // MARK: Say Hello Back
                
                self.recognize ( interpretation( [Interpretation.hello] ) { resume in

                        self.main.speakDialogs([.hello]) {
                                resume(.continueExistingTrain)
                        }

                }, during: [.speakingToUser])
                
                
                
                
                
                
                
                self.recognize ( interpretation( [Interpretation.whyDoYouNeedToSeeMyFace, Interpretation.why], preCondition: { wordCollection, finalInterpretation in
                        
                        return Keeper.person.firstNameRecording != nil
                        
                } ) { resume in
                        
                        guard let firstNameRecording = Keeper.person.firstNameRecording else {
                                resume(.continueExistingTrain)
                                return
                        }
                        
                        self.main.speakDialogs([.becauseINeedToVerifyYouAre]) {
                                self.speechService.playAudioData(firstNameRecording) {
                                        resume(.continueExistingTrain)
                                }
                        }
                        
                }, whileSpeaking: [.iNeedToSeeYourFace, .iAmTryingToGetABetterLookAtYourFace, .couldYouPleaseShowMeYourFace, .isThereAFaceOutThere, .soImGoingToAskYouVariousRandomQuestions, .imGoingToAskYouAFewQuestionsToHelpGetYouBackIn])
                
       
                
                
                
                
                
                
                
                // MARK: *********** Previous Static Administrative Commands ***********
                
                
                
                
                
                
                
                // MARK: Handle User Questions
                
                let iHaveAQuestion = Keeper.offlineSpeechRecognition!.advanced ? Interpretation.CanIAskAQuestion.advancedEnobus : Interpretation.CanIAskAQuestion.enobus
                
                self.recognize ( interpretation([iHaveAQuestion, Interpretation.CanIAskAQuestion.dirtyFinal], type: .requestAskQuestion) { resume in
                        
                        
                        guard !Overseer.actionOccuring(.handlingUserQuestion) else {
                                
                                self.questions.userRequestsAnotherQuestion()
                                return
                        }
                        
                        
                        self.main.onInquiryFinish {
                                resume(.repeatCurrentDialog)
                        }
                        
                        self.questions.enterUserQuestionMode(lastQuestionAsked: self.questions.lastQuestionAsked as? Question, lastQuestionFinishHandler: self.questions.lastQuestionFinishHandler)
                })
                
                
                
                
                
                
                
                
                // MARK: Request Move On
                
                let skippableActions:Set<Action> = [.handlingUserQuestion, .performingHumor, .askProfileQuestion, .displayingPrivacyPolicy, .displayingTermsOfService]
                
                self.recognize ( interpretation([Interpretation.requestMoveOn, Interpretation.requestMoveOnFinal, Interpretation.requestMoveOnExactFinal, Interpretation.goOn], type: .requestMoveOn, preCondition: { _, _ in
                        
                        for action in skippableActions where Overseer.actionOccuring(action) {
                                
                                if action == .askProfileQuestion {
                                        return self.speechService.isSpeaking  // Let regular interpretation handle regular skip requests.
                                }
                                
                                return true
                        }
                        
                        return false
                        
                        
                }) { resume in
                        
                        let occuring = Overseer.actionOccuring
                        
                        
                        if occuring(.handlingUserQuestion) {
                                
                                self.questions.resumeFromUserQuestions()
                                
                                
                        } else if occuring(.performingHumor) {
                                
                                self.main.onInquiryFinish (self.main.humor.finish)
                                self.main.hideAllSupplimentalViews()
                                self.conscious.iWasFunny(humorLevel: .low)
                                self.main.speakDialogs([.sureLetsSkipIt], finished: {
                                        resume(.continueExistingTrain)
                                })
                                
                                
                        } else if occuring(.askProfileQuestion) {
                                
                                self.main.hideAllSupplimentalViews()
                                self.main.speakDialogs([.sure], finished:nil)
                                self.main.moveToNextQuestion()
                                
                                
                        } else if occuring(.displayingPrivacyPolicy) {
                                
                                self.moveOnFromPrivacyPolicy(resume: resume)
                                
                                
                        } else if occuring(.displayingTermsOfService) {
                                
                                self.moveOnFromTermsOfService(resume: resume)
                        }
                })
                
                
                
                
                
                
                
                
                
                // MARK: I Get It
                
                let iGetItActions:Set<Action> = [.handlingUserQuestion, .performingHumor, .displayingPrivacyPolicy, .displayingTermsOfService]
                
                self.recognize ( interpretation([Interpretation.iGetIt, Interpretation.nevermind, Interpretation.imFinished], type: .iGetIt, preCondition: { _, _ in
                        
                        return self.speechService.isSpeaking || Overseer.oneOfActionsInProgress(iGetItActions)
                        
                        
                }) { resume in
                        
                        let occuring = Overseer.actionOccuring
                        
                        
                        if occuring(.handlingUserQuestion) {
                                
                                self.questions.resumeFromUserQuestions()
                                
                                
                        } else if occuring(.performingHumor) {
                                
                                self.main.onInquiryFinish (self.main.humor.finish)
                                self.main.hideAllSupplimentalViews()
                                self.main.speakDialogs([.ok], finished: {
                                        resume(.continueExistingTrain)
                                })
                                
                                
                        } else if occuring(.displayingPrivacyPolicy) {
                                
                                self.moveOnFromPrivacyPolicy(resume: resume)
                                
                                
                        } else if occuring(.displayingTermsOfService) {
                                
                                self.moveOnFromTermsOfService(resume: resume)
                                
                                
                        } else {
                                self.speechService.finishPlaybackImmediately()
                        }
                })
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                // MARK: Can You Repeat The Question
                
                self.recognize ( interpretation( [SpeechInterpretation.CanYouRepeatTheQuestion.enobus] ) { resume in
                        
                        self.speechService.repeatLastQuestionPhrase {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: Can You Repeat That
                
                self.recognize ( interpretation( [SpeechInterpretation.CanYouRepeat.hypothesisEnobus, SpeechInterpretation.CanYouRepeat.finalEnobus], type: .whatDidYouSay) { resume in
                        
                        self.speechService.repeatLastRegularDialog {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                
                // MARK: Before That
                
                self.recognize ( interpretation( [Interpretation.beforeThat], type: .beforeThat, preCondition: { wordCollection, final in
                        
                        previousInquiryMatchesOneOf ([.beforeThat, .whatDidYouSay])
                        
                        
                }) { resume in
                        
                        if let last = self.main.lastUserInquiry.value, last.type == .whatDidYouSay {
                                
                                if let secondToLastDialog = self.speechService.secondToLastRegularDialogSpoken {
                                        self.main.speakDialogs([.beforeThatISaid, secondToLastDialog.identifier], finished: {
                                                resume(.continueExistingTrain)
                                        })
                                } else {
                                        self.main.speakDialogs([.iDidntSayAnythingBeforeThat], finished: {
                                                resume(.continueExistingTrain)
                                        })
                                }
                                
                        } else {
                                self.main.speakDialogs([.iDontRemember]) {
                                        resume(.continueExistingTrain)
                                }
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: Are You OK
                
                self.recognize ( interpretation( [Interpretation.areYouOk] ) { resume in
                        
                        self.main.speakDialogs([.yes, .imFine]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: How Are You
                
                self.recognize ( interpretation( [Interpretation.howAreYou] ) { resume in
                        
                        self.main.speakDialogs([.imFine]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: I'm Thinking
                
                self.recognize ( interpretation( [Interpretation.imThinking] ) { resume in
                        
                        self.main.speakDialogs([.youAreAllowedToThink]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                
                // MARK: Request Picture Story
                
                self.recognize ( interpretation( [Interpretation.requestPictureStory] ) { resume in
                        
                        self.handleRequestPictureStory(resume)
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                

                
                // MARK: I'm Ready
                
                self.recognize ( interpretation( [Interpretation.imReady], preCondition: { wordCollection, final in
                        
                        // Precondition to be met before expensive interpretation takes place.
                        
                        if self.main.holding {
                                return true
                        }
                        
                        if let view = self.viewInterface, view.textsOnScreen.contains(where: { $0.containsStringFromSet(["touch to wake", "hard to hear", "tomorrow", "later"]) }) {
                                
                                return true
                        }
                        
                        return false
                        
                } ) { resume in
                        
                        self.handleImReady(resume)
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                // MARK: Wake Up
                
                self.recognize ( interpretation( [Interpretation.wakeUp] ) { resume in
                        
                        self.handleWakeUp(resume)
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: Request Speed Up
                
                self.recognize ( interpretation([Interpretation.speedUpRequest], preCondition: { _, _ in
                        
                        return self.speechService.capableOfVoiceRateChange
                        
                }) { resume in
                        
                        let before = Date()
                        self.questions.handleRequestSpeedChange(faster: true, firstTime: true) {
                                
                                let now = Date()
                                resume(now.timeIntervalSince(before) > 4 ? .repeatCurrentDialog : .continueExistingTrain)
                        }
                })
                
                
                
                
                // MARK: Request Slow Down
                
                self.recognize ( interpretation([Interpretation.slowDownRequest], preCondition: { _, _ in
                        
                        return self.speechService.capableOfVoiceRateChange
                        
                }) { resume in
                        
                        let before = Date()
                        self.questions.handleRequestSpeedChange(faster: false, firstTime: true) {
                                
                                let now = Date()
                                resume(now.timeIntervalSince(before) > 4 ? .repeatCurrentDialog : .continueExistingTrain)
                        }
                })
                
                
                
                
                
                // MARK: What Are You Doing
                
                self.recognize ( interpretation([Interpretation.whatAreYouDoing]) { resume in
                        
                        if let view = self.viewInterface, view.resting {
                                
                                self.main.speakDialogs([.resting]) {
                                        resume(.continueExistingTrain)
                                }
                                
                        } else {
                                
                                self.main.speakDialogs([.justHangingOut]) {
                                        resume(.continueExistingTrain)
                                }
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                // MARK: Are You Awake
                
                self.recognize ( interpretation([Interpretation.areYouAwake]) { resume in
                        
                        if let view = self.viewInterface, view.resting {
                                
                                self.main.speakDialogs([.no, .imResting]) {
                                        resume(.continueExistingTrain)
                                }
                                
                        } else {
                                
                                self.main.speakDialogs([.yes]) {
                                        resume(.continueExistingTrain)
                                }
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                // MARK: Are You There
                
                self.recognize ( interpretation([Interpretation.areYouThere]) { resume in
                        
                        self.main.speakDialogs([.yesImHere]) {
                                resume(.continueExistingTrain)
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                // MARK: Are You Ready
                
                self.recognize ( interpretation([Interpretation.areYouReady]) { resume in
                        
                        if let view = self.viewInterface, view.resting {
                                
                                self.main.speakDialogs([.no, .imNot, .iNeedSomeRest]) {
                                        resume(.continueExistingTrain)
                                }
                                
                        } else {
                                
                                self.main.speakDialogs([.sure]) {
                                        resume(.continueExistingTrain)
                                }
                        }
                        
                }, notDuring: [.speakingToUser])
                
                
                
                
                
                
                
        }
        
        private func match(fromWords wordsCollection:[String], final:Bool, enobus:Enobus) -> Bool {
                
                return match(fromWords: wordsCollection, final:final, enobii:[enobus])
        }
        
        private func match(fromWords wordsCollection:[String], final:Bool, enobii:[Enobus]) -> Bool {
                
                // Take only the newest phrase.
                guard let words = wordsCollection.first else {
                        return false
                }
                
                for enobus in enobii {
                        
                        guard final || !enobus.requiresFinal else {
                                continue
                        }
                        
                        if final {
                                for words in wordsCollection.dropLast() {
                                        if self.interpretation.matchIn(words, usingEnobus: enobus, noLimit: false) {
                                                return true
                                        }
                                }
                        }
                        
                        if self.interpretation.matchIn(words, usingEnobus: enobus, noLimit: false) {
                                return true
                        }
                }
                
                return false
        }
        
        var now:Date {
                get {
                        return Date()
                }
        }
        
        func handleImReady(_ resume: @escaping ResumeHandler) {
                
                self.main.userSpokeTheyAreReady = self.now
                
                if self.main.holding {
                        Overseer.finish(.handlingUserInquiry, success: true)
                        self.main.becomeReadyToGo()
                        return
                }
                
                guard let view = self.viewInterface else {
                        resume(.continueExistingTrain)
                        return
                }
                
                var dialogs:[Identifier] = []
                for text in view.textsOnScreen {
                        
                        if text.containsIgnoringFormatting("touch to wake") {
                                Overseer.finish(.handlingUserInquiry, success: true)
                                self.main.becomeReadyToGo()
                                return
                                
                        } else if text.containsIgnoringFormatting("hard to hear") {
                                self.main.holding = false
                                Overseer.finish(.handlingUserInquiry, success: true)
                                self.main.assumeReasonableBackgroundNoiseAndContinue()
                                return
                                
                        } else if text.containsStringFromSet(["tomorrow", "later"]) {
                                dialogs.append(.iNeedSomeRest)
                                break
                        }
                }
                
                self.main.speakDialogs(dialogs) {
                        resume(.continueExistingTrain)
                }
        }
        
        func handleWakeUp(_ resume: @escaping ResumeHandler) {
                
                if let view = self.viewInterface, view.resting {
                        
                        let texts = view.textsOnScreen
                        
                        var dialogs:[Identifier] = [.noThankYou]
                        
                        for text in texts {
                                if text.containsIgnoringFormatting("touch to wake") {
                                        self.main.becomeReadyToGo()
                                        return
                                        
                                } else if text.containsIgnoringFormatting("hard to hear") {
                                        self.main.assumeReasonableBackgroundNoiseAndContinue()
                                        return
                                        
                                } else if text.containsStringFromSet(["tomorrow", "later"]) {
                                        dialogs.append(.iNeedSomeRest)
                                        break
                                }
                        }
                        
                        self.main.speakDialogs(dialogs) {
                                resume(.continueExistingTrain)
                        }
                        
                } else {
                        
                        self.main.speakDialogs([.imAwake]) {
                                resume(.continueExistingTrain)
                        }
                }
        }
        
        func handleRequestPictureStory(_ resume: @escaping ResumeHandler) {
                
                guard self.main.mode == .profile, self.main.personValidated else {
                        
                        self.main.speakDialogs([.letsWaitUntilImAskingYouQuestions]) {
                                 resume(.continueExistingTrain)
                        }
                        return
                }
                
                if let question = self.defaultQuestions.getAProfileQuestion(inSpecificCategory: nil, previousQuestion: nil, preferredType: .PictureStory), let storyIdentifier = question.pictureStoryIdentifier {
                        
                        self.main.hideAllSupplimentalViews()
                        
                        self.main.speakDialogsWithIntermissions([(.sure, 0.0), (.iHaveAPictureStoryForYou, 0.5)]) {
                                
                                self.viewInterface?.showLoading(true)
                                
                                self.main.speakDialogsWithIntermissions([(.hereWeGo, 0.5)]) {
                                        
                                        self.viewInterface?.showLoading(false)
                                        
                                        Overseer.finish(.handlingUserInquiry, success: true)
                                        
                                        self.main.pictureStoriesConversation.beginPictureStory(storyIdentifier, completion: {
                                                self.main.askProfileQuestions()
                                        })
                                }
                        }
                        
                } else {
                        
                        func ask() {
                                
                                self.main.speakDialogs([.sorryIAmOutOfPictureStories, .wouldYouLikeToSendUsSomeIdeasForMore], listenAfter: .wouldYouLikeToSendUsSomeIdeasForMore, listen: { _ in
                                        
                                        self.speechService.listenForYesOrNo { answer, inquiry in
                                                if let type = inquiry {
                                                        self.main.handleUserInquiry(type, finished: { longBreak, resumeType in
                                                                ask()
                                                        })
                                                        return
                                                }
                                                
                                                if answer == true {
                                                        
                                                        self.questions.askUserWhatTheyWouldLikeToSayToSupport {
                                                                resume(.repeatCurrentDialog)
                                                        }
                                                        
                                                } else {
                                                        
                                                        self.main.speakDialogs([.ok]) {
                                                                resume(.repeatCurrentDialog)
                                                        }
                                                }
                                        }
                                        
                                }, finished: nil)
                        }
                        
                        ask()
                }
        }
        
        func moveOnFromPrivacyPolicy(resume: ResumeHandler?) {
                
                guard let finished = self.main.payment.finishedWalkingThroughPrivacy else {
                        resume?(.continueExistingTrain)
                        return
                }
                
                self.main.speakDialogs([.sure, .letsMoveOn], finished: {
                        self.main.finish(.displayingPrivacyPolicy, success:false)
                        finished()
                })
        }
        
        func moveOnFromTermsOfService(resume: ResumeHandler?) {
                
                guard let finished = self.main.payment.finishedWalkingThroughTermsOfService else {
                        resume?(.continueExistingTrain)
                        return
                }
                
                self.main.speakDialogs([.sure], finished: {
                        self.main.payment.askForAgreement(finished: {
                                self.main.finish(.displayingTermsOfService, success:false)
                                finished()
                        })
                })
        }
}

/**
 A wrapper for dicitonary which contains convenience methods for adding reactions to triggers.
 */
public class TriggersToReactions<Trigger: Hashable> {
        
        subscript(key: Trigger) -> [Reaction]? {
                get {
                        return self.values[key]
                }
                set {
                        self.values[key] = newValue
                }
        }
        
        var values:[Trigger: [Reaction]] = [:]
        
        func add(_ reaction: @escaping Reaction, toTrigger trigger:Trigger) {
         
                var reactions:[Reaction]? = self[trigger]
                if reactions == nil {
                        reactions = []
                }
                reactions?.append(reaction)
                self[trigger] = reactions
        }
}
