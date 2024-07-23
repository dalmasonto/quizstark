mod mytypes;
mod upgrade;

use starknet::ContractAddress;
use quiz_contract::mytypes::{QuestionID, QuizID, OptionID, SubmissionID};


#[derive(starknet::Store, Drop, Copy, Serde)]
struct Quiz {
    id: QuizID,
    title: felt252,
    description: felt252,
    total_questions: u8,
    total_submissions: u256,
    creator: ContractAddress
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

#[derive(starknet::Store, Drop, Copy, Serde)]
struct SubmittedQuiz {
    quiz_id: QuizID,
    participant: ContractAddress,
    id: QuizID,
    score: u32,
    total_questions_submitted: u8,
    current_question: QuestionID,
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
        ref self: TContractState, quiz_id: QuizID, text: felt252, correct_option: u8
    );
    fn create_option(
        ref self: TContractState,
        quiz_id: QuizID,
        question_id: QuestionID,
        text: felt252,
        is_correct: bool,
        correct_option: u8
    );
    fn get_question(
        self: @TContractState, quiz_id: QuizID, question_id: QuestionID
    ) -> QuestionWithOptions;
    fn get_normal_question(
        self: @TContractState, quiz_id: QuizID, question_id: QuestionID
    ) -> Question;
    fn get_questions(self: @TContractState, quiz_id: QuizID) -> Array<QuestionWithOptions>;

    fn submit_question(
        ref self: TContractState, quiz_id: QuizID, question_id: QuestionID, optionID: u8
    );

    fn get_participant_submissions(
        self: @TContractState, participantAddress: ContractAddress
    ) -> Array<SubmittedQuiz>;

    fn get_submission(self: @TContractState, submissionID: SubmissionID) -> SubmittedQuiz;
    fn get_total_submissions(self: @TContractState) -> u256;
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

    use quiz_contract::upgrade::IUpgradeableContract;
    use starknet::{SyscallResultTrait, ClassHash};

    #[storage]
    struct Storage {
        quizzes: LegacyMap<QuizID, Quiz>,
        quizzes_count: u256,
        questions: LegacyMap<(QuizID, QuestionID), Question>,
        question_options: LegacyMap<(QuizID, QuestionID, OptionID), QuestionOption>,
        submissions: LegacyMap<SubmissionID, SubmittedQuiz>,
        submissions_count: u256,
        quiz_submissions: LegacyMap<(QuizID, SubmissionID), SubmissionID>,
        participant_submissions: LegacyMap<(ContractAddress, QuizID), SubmissionID>,
        participant_quiz_submissions: LegacyMap<(ContractAddress, u256), SubmissionID>,
        participants: LegacyMap::<ContractAddress, Participant>,
        submitted_questions: LegacyMap<(ContractAddress, QuizID, QuestionID), bool>,
    }

    #[abi(embed_v0)]
    impl IQuizImpl of super::IQuiz<ContractState> {
        fn create_participant(ref self: ContractState) {
            let participantAddress = get_caller_address();
            let participant = self.get_participant(participantAddress);
            if participant.id.is_zero() {
                let newParticipant = Participant { id: participantAddress, total_submissions: 0 };
                self.participants.write(participantAddress, newParticipant);
            }
        }
        fn get_participant(
            self: @ContractState, participantAddress: ContractAddress
        ) -> Participant {
            self.participants.read(participantAddress)
        }

        fn create_quiz(ref self: ContractState, title: felt252, description: felt252) {
            let quiz_id = self.quizzes_count.read() + 1;
            let participantAddress = get_caller_address();
            let quiz = Quiz {
                id: quiz_id,
                title,
                description,
                total_questions: 0,
                total_submissions: 0,
                creator: participantAddress
            };
            self.quizzes.write(quiz_id, quiz);
            self.quizzes_count.write(quiz_id);
        // Emit events here
        }

        fn get_quiz(self: @ContractState, quiz_id: QuizID) -> Quiz {
            self.quizzes.read(quiz_id)
        }

        fn create_question(
            ref self: ContractState, quiz_id: QuizID, text: felt252, correct_option: u8
        ) {
            let mut quiz = self.get_quiz(quiz_id);
            let question_id = quiz.total_questions + 1;
            quiz.total_questions = question_id;
            let mut question = Question {
                quiz_id, id: question_id, text, options_count: 0, correct_option,
            };

            self.questions.write((quiz_id, question_id), question);
            self.quizzes.write(quiz_id, quiz);
        }

        fn create_option(
            ref self: ContractState,
            quiz_id: QuizID,
            question_id: QuestionID,
            text: felt252,
            is_correct: bool,
            correct_option: u8
        ) {
            let mut question = self.get_normal_question(quiz_id, question_id);
            let mut optionIndex: u8 = question.options_count;
            let mut my_option: QuestionOption = QuestionOption {
                id: optionIndex, question_id, text, is_correct,
            };
            self.question_options.write((quiz_id, question_id, optionIndex), my_option);
            optionIndex += 1;
            question.options_count = optionIndex;
            self.questions.write((quiz_id, question_id), question);
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

        fn get_normal_question(
            self: @ContractState, quiz_id: QuizID, question_id: QuestionID
        ) -> Question {
            self.questions.read((quiz_id, question_id))
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

        fn submit_question(
            ref self: ContractState, quiz_id: QuizID, question_id: QuestionID, optionID: u8
        ) {
            let participant = get_caller_address();
            let has_submitted = self
                .submitted_questions
                .read((participant, quiz_id, question_id));

            if !has_submitted {
                // Update total submissions of a given quiz
                let mut quiz = self.get_quiz(quiz_id);
                quiz.total_submissions += 1;

                // Query the submitted quiz
                let submittedQuizID = self
                    .participant_submissions
                    .read((participant, quiz_id));

                let newSubmissionID = self.submissions_count.read() + 1;

                if submittedQuizID == 0 {
                    let option = self
                        .question_options
                        .read((quiz_id, question_id, optionID));
                    let mut score = 0;

                    if option.is_correct {
                        score = 1;
                    }

                    let mut submission = SubmittedQuiz {
                        id: newSubmissionID,
                        participant,
                        quiz_id,
                        score: score,
                        total_questions_submitted: 1,
                        current_question: question_id,
                    };

                    self.submissions.write(newSubmissionID, submission);
                    self.submitted_questions.write((participant, quiz_id, question_id), true);
                    self.submissions_count.write(newSubmissionID);
                    self.participant_submissions.write((participant, quiz_id), newSubmissionID);
                    // Create a participant account if the current question matches the total questions
                    if submission.total_questions_submitted == quiz.total_questions {
                        let mut participant_account = self
                            .participants
                            .read(participant);
                        participant_account.total_submissions += 1;

                        self
                            .participant_quiz_submissions
                            .write(
                                (participant, participant_account.total_submissions),
                                newSubmissionID
                            );
                        self.participants.write(participant, participant_account);
                    }
                } else {
                    let mut submission = self.submissions.read(submittedQuizID);

                    let option = self
                        .question_options
                        .read((quiz_id, question_id, optionID));

                    if option.is_correct {
                        submission.score += 1;
                    }

                    submission.total_questions_submitted += 1;
                    submission.current_question = question_id;

                    self.submissions.write(submission.id, submission);
                    self.submitted_questions.write((participant, quiz_id, question_id), true);

                    // Create a participant account if the current question matches the total questions
                    if submission.total_questions_submitted == quiz.total_questions {
                        let mut participant_account = self
                            .participants
                            .read(participant);
                        participant_account.total_submissions += 1;

                        self
                            .participant_quiz_submissions
                            .write(
                                (participant, participant_account.total_submissions), submission.id
                            );
                        self.participants.write(participant, participant_account);
                    }
                }

                // Write back the updated quiz
                self.quizzes.write(quiz_id, quiz);
            }
        }


        fn get_participant_submissions(
            self: @ContractState, participantAddress: ContractAddress
        ) -> Array<SubmittedQuiz> {
            let mut participantSubmissions = ArrayTrait::<SubmittedQuiz>::new();
            let participant = self.participants.read(participantAddress);
            let total_submissions = participant.total_submissions;
            let mut count = 0;

            loop {
                if (count == total_submissions) {
                    break;
                }
                let submissionID = self
                    .participant_quiz_submissions
                    .read((participantAddress, count + 1));
                let submission = self.submissions.read(submissionID);
                participantSubmissions.append(submission);
                count += 1;
            };

            participantSubmissions
        }

        fn get_submission(self: @ContractState, submissionID: SubmissionID) -> SubmittedQuiz {
            self.submissions.read(submissionID)
        }

        fn get_total_submissions(self: @ContractState) -> u256 {
            self.submissions_count.read()
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableContract of IUpgradeableContract<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(impl_hash.is_non_zero(), 'Class hash cannot be zero');
            starknet::syscalls::replace_class_syscall(impl_hash).unwrap_syscall();
        }
    }
}

