// Metaprogram plugin to check procedures that take struct pointers as parameters, and report them
// if it seems that the parameter could just as well be maybe-by-reference instead, such that the
// programmer can omit the * from the parameter's type.

// Currently does not work with `using`, but soon, hopefully!

#scope_module;
get_plugin :: () -> *Metaprogram_Plugin {
    p := *my_plugin;

    p.before_intercept = null;  // Not needed.
    p.add_source       = null;  // Not needed.
    p.message          = check_procedures_with_struct_pointer_parameters_to_see_if_they_need_not_be;
    p.finish           = null;  // Not needed.
    p.shutdown         = null;  // Not needed.

    return p;
}

#scope_export;

check_procedures_with_struct_pointer_parameters_to_see_if_they_need_not_be :: (p: *Metaprogram_Plugin, message: *Message) {
    if message.kind != .TYPECHECKED then return;
    for (cast(*Message_Typechecked) message).procedure_bodies {
        // Check to see if the procedure is one we care about -- if not, continue
        is_relevant, pointer_to_struct_parameters := check_procedure_header(it.expression.header);
        if !is_relevant then continue;

        pointer_to_struct_parameters_invoked_by_pointer: [..] *Code_Declaration;
        pointer_to_struct_parameters_mutated_or_used:    [..] *Code_Declaration;

        for it.subexpressions {
            if it.kind == {

            case .PROCEDURE_CALL;
                // Make sure it's actually a procedure call and not a parameterized struct instatiation -- otherwise continue
                procedure_call := cast(*Code_Procedure_Call) it;
                if procedure_call.resolved_procedure_expression.kind != .PROCEDURE_HEADER then continue;

                invoked_procedure_header := cast(*Code_Procedure_Header) procedure_call.resolved_procedure_expression;

                for procedure_call.arguments_sorted {
                    if it.kind == .IDENT {
                        ident := cast(*Code_Ident) it;
                        relevant_pointer_to_struct_parameter_index := -1;
                        for pointer_to_struct_parameters if it.name == ident.name { relevant_pointer_to_struct_parameter_index = it_index; break; }
                        if relevant_pointer_to_struct_parameter_index == -1 then continue;
                        relevant_pointer_to_struct_parameter := pointer_to_struct_parameters[relevant_pointer_to_struct_parameter_index];
                        procedure_argument := invoked_procedure_header.arguments[it_index];
                        if !procedure_argument.type_inst            then continue;
                        if !procedure_argument.type_inst.pointer_to then continue;
                        if procedure_argument.type_inst.pointer_to.result == cast(*Type_Info_Struct) relevant_pointer_to_struct_parameter.type_inst.pointer_to.result then array_add_if_unique(*pointer_to_struct_parameters_invoked_by_pointer, relevant_pointer_to_struct_parameter);
                    }
                }
            
            case .BINARY_OPERATOR;
                binary_operation := cast(*Code_Binary_Operator) it;
                if binary_operation.left.kind == .IDENT {
                    ident := cast(*Code_Ident) binary_operation.left;
                    for pointer_to_struct_parameters if it.name == ident.name then array_add_if_unique(*pointer_to_struct_parameters_mutated_or_used, it);
                }
                if binary_operation.right.kind == .IDENT {
                    ident := cast(*Code_Ident) binary_operation.right;
                    for pointer_to_struct_parameters if it.name == ident.name then array_add_if_unique(*pointer_to_struct_parameters_mutated_or_used, it);
                }

            case .UNARY_OPERATOR;
                unary_operation := cast(*Code_Unary_Operator) it;
                if unary_operation.subexpression.kind == .IDENT {
                    ident := cast(*Code_Ident) unary_operation.subexpression;
                    for pointer_to_struct_parameters if it.name == ident.name then array_add_if_unique(*pointer_to_struct_parameters_mutated_or_used, it);
                }


            case .DECLARATION;
                declaration := cast(*Code_Declaration) it;
                if declaration.expression.kind == .IDENT {
                    ident := cast(*Code_Ident) declaration.expression;
                    for pointer_to_struct_parameters if it.name == ident.name then array_add_if_unique(*pointer_to_struct_parameters_mutated_or_used, it);
                }

            }
        }
        procedure_header := it.expression.header;
        for pointer_to_struct_parameters if
            !array_find(pointer_to_struct_parameters_invoked_by_pointer, it) &&
            !array_find(pointer_to_struct_parameters_mutated_or_used,    it)
        then report_unnecessary_struct_pointer_parameter(procedure_header, it);
    }
}

check_procedure_header :: (using header: Code_Procedure_Header) -> is_relevant: bool, pointer_to_struct_parameters: [] *Code_Declaration {
    for #run(type_of(Code_Procedure_Header.procedure_flags)).[
        .C_CALL,
        .CPP_METHOD,
    ] if procedure_flags & it                                                    then return false, .[];
    if foreign_function_name                                                     then return false, .[];
    if arguments.count == 0                                                      then return false, .[];
    if body_or_null.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM then return false, .[];
    pointer_to_struct_parameters: [..] *Code_Declaration;
    for arguments {
        if !it.type_inst                                   then continue;
        if !it.type_inst.pointer_to                        then continue;
        if  it.type_inst.pointer_to.result.type != .STRUCT then continue;
        array_add(*pointer_to_struct_parameters, it);
    }
    return pointer_to_struct_parameters.count > 0, pointer_to_struct_parameters;
}

report_unnecessary_struct_pointer_parameter :: (procedure_header: *Code_Procedure_Header, parameter: *Code_Declaration) {
    message := "Unnecessary pointer-to-struct parameter '%' (type %): pointerness is not utilized, so the parameter can be passed maybe-by-reference (without the `*`) instead.";
    error   := sprint(message, parameter.name, (cast(*Type_Info_Struct) parameter.type_inst.pointer_to.result).name);
    compiler_report(error, make_location(parameter.type_inst), .WARNING);
}

my_plugin: Metaprogram_Plugin;

#import "Compiler";
#import "Basic";
