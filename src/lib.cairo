mod mytypes;

use starknet::ContractAddress;
use quiz_contract::mytypes::{QuestionID, QuizID, OptionID};


#[derive(starknet::Store, Drop, Copy, Serde)]
struct Quiz {
    id: QuizID,
    title: felt252,
    description: felt252,
    total_questions: u8,
    total_submissions: u256,
}

#[derive(starknet::Store, Drop, Copy, Serde, Desctruct)]
struct Question {
    quiz_id: QuizID,
    id: QuestionID,
    text: felt252,
    correct_option: u8,
    options_count: u8
}

#[derive(Drop, Serde)]
struct QuestionWithOptions {
    quiz_id: QuizID,
    id: QuestionID,
    text: felt252,
    options: Array<QuestionOptionRead>
}

#[derive(starknet::Store, Drop, Copy, Serde, Destruct)]
struct QuestionOptionRead {
    id: OptionID,
    question_id: QuestionID,
    text: felt252,
}


#[derive(starknet::Store, Drop, Copy, Serde, Destruct)]
struct QuestionOption {
    id: OptionID,
    question_id: QuestionID,
    text: felt252,
    is_correct: bool,
}

#[derive(starknet::Store, Drop, Copy)]
struct SubmittedQuiz {
    quiz_id: QuizID,
    participant: ContractAddress,
    id: QuizID,
    score: u32
}

#[derive(starknet::Store, Copy, Drop, Serde, Destruct)]
struct SubmittedOption {
    submited_quiz: QuizID,
    question_id: QuestionID,
    id: QuizID,
    option_id: OptionID
}

#[derive(starknet::Store, Drop)]
struct Score {
    points: u128,
}

#[derive(starknet::Store, Drop, Copy, Serde)]
struct Participant {
    id: ContractAddress,
    total_submissions: u256,
}

// #[derive(Default, serde::Serde)]
#[starknet::interface]
pub trait IQuiz<TContractState> {
    fn create_participant(ref self: TContractState);
    fn get_participant(self: @TContractState, participantAddress: ContractAddress) -> Participant;
    fn create_quiz(ref self: TContractState, title: felt252, description: felt252);
    fn get_quiz(self: @TContractState, quiz_id: QuizID) -> Quiz;
    fn create_question(
        ref self: TContractState,
        quiz_id: QuizID,
        text: felt252,
        options: Array<QuestionOption>,
        correct_option: u8
    );
    fn get_question(
        self: @TContractState, quiz_id: QuizID, question_id: QuestionID
    ) -> QuestionWithOptions;
    fn get_questions(self: @TContractState, quiz_id: QuizID) -> Array<QuestionWithOptions>;
    fn submit_quiz(
        ref self: TContractState, quiz_id: QuizID, submitted_options: Array<SubmittedOption>
    );
// fn initialize_score(ref self: TContractState, participant: ContractAddress);
// fn update_score(ref self: TContractState, participant: ContractAddress, points: u128);
// fn get_score(self: @TContractState, participant: ContractAddress) -> Score;
// fn answer_question(
//     self: @TContractState,
//     quiz_id: u32,
//     question_id: u32,
//     participant: ContractAddress,
//     selected_option: u8
// ) -> bool;
}

#[starknet::contract]
mod QuizContract {
    use core::num::traits::zero::Zero;
    use core::array::ArrayTrait;
    use quiz_contract::IQuiz;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use quiz_contract::mytypes::SubmissionID;
    use starknet::get_caller_address;
    use super::{
        QuizID, Quiz, Question, QuestionOption, ContractAddress, Score, QuestionID,
        QuestionWithOptions, QuestionOptionRead, SubmittedOption, SubmittedQuiz, Participant,
        OptionID
    };
    use core::{zeroable, zeroable::{NonZero}};

    #[storage]
    struct Storage {
        quizzes: LegacyMap<QuizID, Quiz>,
        quizzes_count: u256,
        questions: LegacyMap<(QuizID, QuestionID), Question>,
        question_options: LegacyMap<(QuizID, QuestionID, OptionID), QuestionOption>,
        quiz_submissions: LegacyMap<(QuizID, SubmissionID), SubmittedQuiz>,
        participant_submissions: LegacyMap<(ContractAddress, QuizID), SubmissionID>,
        participant_quiz_submissions: LegacyMap<
            (ContractAddress, SubmissionID), (QuizID, SubmissionID)
        >,
        participants: LegacyMap::<ContractAddress, Participant>,
    }

    #[abi(embed_v0)]
    impl IQuizImpl of super::IQuiz<ContractState> {
        fn create_participant(ref self: ContractState) {
            let participantAddress = get_caller_address();
            let participant = self.get_participant(participantAddress);
            if participant.id.is_zero() {
                self
                    .participants
                    .write(
                        participantAddress,
                        Participant { id: participantAddress, total_submissions: 0 }
                    );
            }
        }
        fn get_participant(
            self: @ContractState, participantAddress: ContractAddress
        ) -> Participant {
            let participantAddress = get_caller_address();
            self.participants.read(participantAddress)
        }

        fn create_quiz(ref self: ContractState, title: felt252, description: felt252) {
            let quiz_id = self.quizzes_count.read() + 1;
            let quiz = Quiz {
                id: quiz_id, title, description, total_questions: 0, total_submissions: 0
            };
            self.quizzes.write(quiz_id, quiz);
        // Emit events here
        }

        fn get_quiz(self: @ContractState, quiz_id: QuizID) -> Quiz {
            self.quizzes.read(quiz_id)
        }

        fn create_question(
            ref self: ContractState,
            quiz_id: QuizID,
            text: felt252,
            options: Array<QuestionOption>,
            correct_option: u8
        ) {
            let mut quiz = self.get_quiz(quiz_id);
            let question_id = quiz.total_questions + 1;
            quiz.total_questions = question_id;
            let mut question = Question {
                quiz_id,
                id: question_id,
                text,
                options_count: options.len().try_into().unwrap(),
                correct_option,
            };

            self.questions.write((quiz_id, question_id), question);
            let mut optionIndex: u8 = 0;

            loop {
                if optionIndex == options.len().try_into().unwrap() {
                    break;
                }
                let mut my_option: QuestionOption = *options[optionIndex.try_into().unwrap()];
                my_option.id = optionIndex.try_into().unwrap();
                my_option.question_id = question_id;
                self.question_options.write((quiz_id, question_id, optionIndex), my_option);
                optionIndex += 1;
            };
            self.quizzes.write(quiz_id, quiz);
        }
        fn get_question(
            self: @ContractState, quiz_id: QuizID, question_id: QuestionID
        ) -> QuestionWithOptions {
            let question = self.questions.read((quiz_id, question_id));
            let mut options = ArrayTrait::<QuestionOptionRead>::new();
            let mut optionIndex = 0;

            let mut return_quiz = QuestionWithOptions {
                quiz_id, id: question_id, text: question.text, options: ArrayTrait::new()
            };

            loop {
                if question.options_count == optionIndex {
                    break;
                }
                let option = self.question_options.read((quiz_id, question_id, optionIndex));
                let questionOptionRead = QuestionOptionRead {
                    id: optionIndex, text: option.text, question_id: question_id,
                };
                options.append(questionOptionRead);
                optionIndex += 1;
            };
            return_quiz.options = options;
            return_quiz
        }

        fn get_questions(self: @ContractState, quiz_id: QuizID) -> Array<QuestionWithOptions> {
            let mut questions = ArrayTrait::<QuestionWithOptions>::new();
            let quiz = self.get_quiz(quiz_id);
            let mut question_id = 0;

            loop {
                if quiz.total_questions == question_id {
                    break;
                }
                let questionWithOptions = self.get_question(quiz_id, question_id + 1);
                questions.append(questionWithOptions);
                question_id += 1;
            };

            questions
        }
        fn submit_quiz(
            ref self: ContractState, quiz_id: QuizID, submitted_options: Array<SubmittedOption>
        ) {
            let participant = get_caller_address();
            let has_submitted = self.participant_submissions.read((participant, quiz_id));

            if has_submitted == 0 {
                let mut quiz = self.get_quiz(quiz_id);
                let submission_id = quiz.total_submissions + 1;
                quiz.total_submissions = submission_id;
                let mut submittedOptionIndex = 0;
                let mut score = 0;

                loop {
                    if submittedOptionIndex == submitted_options.len() {
                        break;
                    }
                    let _submittedOption = *submitted_options[submittedOptionIndex];
                    let _reallyOption = self
                        .question_options
                        .read((quiz_id, _submittedOption.question_id, _submittedOption.option_id));
                    if _reallyOption.is_correct {
                        score += 1;
                    }
                    submittedOptionIndex += 1;
                };

                let submittedQuiz = SubmittedQuiz {
                    quiz_id, participant, id: submission_id, score
                };
                self.quiz_submissions.write((quiz_id, submission_id), submittedQuiz);
                self.participant_submissions.write((participant, quiz_id), submission_id);
                self.quizzes.write(quiz_id, quiz);

                let mut participantAcc = self.participants.read(participant);
                let participantSubmissionID = participantAcc.total_submissions + 1;

                self
                    .participant_quiz_submissions
                    .write((participant, participantSubmissionID), (quiz_id, submission_id));
            }
        }
    }
}
