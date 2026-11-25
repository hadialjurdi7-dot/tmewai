/// SQL predicate matching every stored message event, whatever payload it
/// carried.
///
/// A text message is stored as `message`; a message whose body is empty is
/// stored as `message_photo`, `message_link`, `message_call`, and so on. Every
/// message aggregate must include both, or a photo-only thread would vanish
/// from the messages list, the person profile and the KPI counts.
///
/// [column] is an internal column expression chosen by the caller, never user
/// input.
String messageEventSql(String column) =>
    "($column = 'message' OR $column LIKE 'message!_%' ESCAPE '!')";
