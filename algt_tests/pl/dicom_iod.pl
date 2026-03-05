
dcm_iod_module('CT Image', 'Patient', mandatory).
dcm_iod_module('CT Image', 'General Study', mandatory).
dcm_iod_module('RT Plan', 'Patient', mandatory).

dcm_module_attr('Patient', 'Patient ID',   type1).
dcm_module_attr('Patient', 'Patient Name', type1).
dcm_module_attr('Patient', 'Patient DOB',  type2).
dcm_module_attr('Patient', 'Patient Gender', type2).

dcm_module_attr('General Image', 'Slice Number', type2c(dcm_slice_number_ok)).

dcm_slice_number_ok([dcm_attr('Slice Number', SliceNumber), Image | _]) :-
	dcm_attr_find(Image, dcm_attr('Slice Location', _, SliceLocation)),
	SliceNumber = SliceLocation.


dcm_ok(Instance) :-
	dcm_iod(IOD),
	forall(dcm_iod_module(IOD, Module),
	       (
	       %%
	       %% check type 1 attribute
	       dcm_module_attr(Module, Attr, type1),
		dcm_attr_find(dcm_attr(Attr, Content), Instance),
		not(dcm_null(Content))) 
	       ; 
	       
	       %%
	       %% check type 1c attribute
	       dcm_module_attr(Module, Attr, type1c(CondPred)),
	       (
	       %% check the condition
	       Cond =.. [CondPred, [Instance | _]],
		Cond,
		dcm_attr_find(dcm_attr(Attr, Content)),
		not(dcm_null(Content)) ;
	       
	       %% condition fails, check attribute not present
	       not(dcm_attr_find(dcm_attr(Attr, _)))
	       ) 
	       ;
	       
	       %%
	       %% check type 2 attribute
	       dcm_module_attr(Module, Attr, type2),
	       dcm_attr_find(dcm_attr(Attr, Content), Instance)
	       ;
	       
	       %%
	       %% check type 2c attribute
	       dcm_module_attr(Module, Attr, type2c(CondPred)),
	       
	       %% check the condition
	       Cond =.. [CondPred, [Instance | _]],
	       Cond, 
	       dcm_attr_find(dcm_attr(Attr, Content)) 
	       
	      ), 
	once.

		    


