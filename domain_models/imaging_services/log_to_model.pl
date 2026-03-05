dcg_model_log(Model, State, Log) :-
    true.

import_review_loop(Model, State, Log) :-
    additive_blend('CpuBlender') ;
    additive_blend_emscripten('CpuBlender') ;
    additive_blend_anat0mixer('ZBModel') ;
    additive_blend_warptps('Landmarks',
                           'Matching') ;
    visual_narrative_review('SpeechRecognition',
                            'MouseTouchEvents') ;
    vsa_offset_predicates ;
    sro_decoder_ring('SroDecoderModel',
                     'RotationModel') ;
    offset_visualization('RegistrationView',
                         'RegistrationViewModel') ;
    stereo_2d_3d_review.
