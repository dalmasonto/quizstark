// #[starknet::contract]
// mod QuizContract {
//     use starknet::{ContractAddress, get_caller_address, storage_access::StorageBaseAddress};
//     use super::{Question, Quiz};

//     #[storage]
//     struct Storage {
//         quizzes: LegacyMap<u32, Quiz>,
//         questions: LegacyMap<(u32, u256), Question>,
//         scores: LegacyMap::<ContractAddress, Score>,
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     enum Event {
//         CorrectAnswer,
//         IncorrectAnswer,
//     }

//     #[abi(embed_v0)]
//     impl Quiz of super::IQuiz<ContractState> {
//         fn set_quiz(ref self: TContractState, quiz_id: u32, title: felt252, description: felt252) {
//             let new_quiz = Quiz {
//                 title, description, questions: LegacyMap::new(), total_questions: 0,
//             };
//             self.quizzes.write(quiz_id, new_quiz);
//         }

//         fn set_question(
//             ref self: TContractState,
//             quiz_id: u32,
//             question_id: u32,
//             text: felt252,
//             options: LegacyMap::<u8, felt252>,
//             correct_option: u8
//         ) {
//             let new_question = Question {
//                 text, options, correct_option, is_answered: LegacyMap::new(),
//             };
//             self.quizzes[quiz_id].questions.write(question_id, new_question);
//             self.quizzes[quiz_id].total_questions += 1;
//         }

//         fn get_question(self: @TContractState, quiz_id: u32, question_id: u32) -> Question {
//             self.quizzes[quiz_id].questions.get(question_id).unwrap()
//         }

//         fn initialize_score(ref self: TContractState, participant: ContractAddress) {
//             let new_score = Score { points: 0 };
//             self.scores.write(participant, new_score);
//         }

//         fn update_score(ref self: TContractState, participant: ContractAddress, points: u128) {
//             let mut score = self.scores.get(participant).unwrap();
//             score.points += points;
//             self.scores.write(participant, score);
//         }

//         fn get_score(self: @TContractState, participant: ContractAddress) -> Score {
//             self.scores.get(participant).unwrap()
//         }

//         fn answer_question(
//             self: @TContractState,
//             quiz_id: u32,
//             question_id: u32,
//             participant: ContractAddress,
//             selected_option: u8
//         ) -> bool {
//             let mut question = self.quizzes[quiz_id].questions.get(question_id).unwrap();
//             question.is_answered.insert(participant, true);

//             let is_correct = question.correct_option == selected_option;
//             if is_correct {
//                 self.update_score(participant, 1);
//                 Event::CorrectAnswer.emit();
//             } else {
//                 Event::IncorrectAnswer.emit();
//             }

//             self.quizzes[quiz_id].questions.write(question_id, question);
//             is_correct
//         }
//     }

//     #[abi(embed_v0)]
//     #[generate_trait]
//     impl QuizContractPrivate of PrivateTrait {
//         fn create_quiz(self: @ContractState, quiz_id: u32, title: felt252, description: felt252) {
//             self.storage.set_quiz(quiz_id, title, description);
//         }

//         fn add_question(
//             self: @ContractState,
//             quiz_id: u32,
//             question_id: u32,
//             text: felt252,
//             options: LegacyMap::<u8, felt252>,
//             correct_option: u8
//         ) {
//             self.storage.set_question(quiz_id, question_id, text, options, correct_option);
//         }

//         fn submit_answer(
//             self: @ContractState,
//             quiz_id: u32,
//             question_id: u32,
//             participant: ContractAddress,
//             selected_option: u8
//         ) -> bool {
//             self.storage.answer_question(quiz_id, question_id, participant, selected_option)
//         }

//         fn get_participant_score(self: @ContractState, participant: ContractAddress) -> @Score {
//             self.storage.get_score(participant)
//         }
//     }
// }