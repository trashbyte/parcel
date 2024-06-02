import 'dart:core';

typedef AnyPredicate = bool Function(dynamic);

enum TypeOfTag {
    string, number, boolean, map, function;

    bool check(dynamic value) {
        switch (this) {
            case TypeOfTag.string:
                return value is String;
            case TypeOfTag.number:
                return value is num;
            case TypeOfTag.boolean:
                return value is bool;
            case TypeOfTag.map:
                return value is Map;
            case TypeOfTag.function:
                return value is Function;
        }
    }

    @override String toString() {
        switch (this) {
            case TypeOfTag.string:
                return "string";
            case TypeOfTag.number:
                return "number";
            case TypeOfTag.boolean:
                return "boolean";
            case TypeOfTag.map:
                return "map";
            case TypeOfTag.function:
                return "function";
        }
    }
}

class ArrayValidators {
    bool? nonEmpty;
    AnyPredicate? validateFirst;
    AnyPredicate? validateEach;

    ArrayValidators({this.nonEmpty, this.validateFirst, this.validateEach});
}

class TypeValidator<T> {
    Set<String> simpleFields = {};
    Map<String, ArrayValidators?> arrayFields = {};
    Map<String, TypeOfTag> primitiveFields = {};
    Map<String, AnyPredicate> predicateFields = {};
    Map<String, TypeValidator<dynamic>> objectFields = {};

    TypeValidator<T> withField(String name, AnyPredicate? predicate) {
        if (predicate != null) {
            this.predicateFields[name] = predicate;
        }
        else {
            this.simpleFields.add(name);
        }
        return this;
    }

    TypeValidator<T> withPrimitiveField(String name, TypeOfTag type) {
        this.primitiveFields[name] = type;
        return this;
    }

    TypeValidator<T> withArrayField(String name, ArrayValidators? validators) {
        this.arrayFields[name] = validators;
        return this;
    }

    TypeValidator<T> withObjectField(String name, TypeValidator<dynamic> sub) {
        this.objectFields[name] = sub;
        return this;
    }

    (T?, List<String>) validate(dynamic value) {
        return this._validateInternal(value, "");
    }

    (T?, List<String>) _validateInternal(dynamic value, String path) {
        List<String> errors = [];
        var pathStr = path.isEmpty ? "" : " Path: $path";
        if (value == null) {
            return (null, ["Validation failed: value was null or undefined.$pathStr"]);
        }
        else if (value is Map) {
            for (var name in this.simpleFields) {
                if (!value.containsKey(name)) {
                    errors.add("Validation failed: value missing field '$name'.$pathStr");
                }
            }
            for (var entry in this.arrayFields.entries) {
                var name = entry.key;
                var validators = entry.value;
                if (!value.containsKey(name)) {
                    errors.add("Validation failed: value missing field '$name'.$pathStr");
                    continue;
                }
                if (validators == null) {
                    continue;
                }
                dynamic arr = value[name];
                if (arr is! List) {
                    errors.add("Validation failed: field '$name' was not an array.$pathStr");
                    continue;
                }
                if (validators.nonEmpty == true && arr.isEmpty) {
                    errors.add("Validation failed: array field '$name' must be non-empty.$pathStr");
                    continue;
                }
                if (arr.isNotEmpty && validators.validateFirst != null) {
                    if (!validators.validateFirst!(arr[0])) {
                        errors.add("Validation failed: first element of array '$name' failed validation.$pathStr");
                    }
                }
                if (arr.isNotEmpty && validators.validateEach != null) {
                    if (arr.any((x) => !validators.validateEach!(x))) {
                        errors.add("Validation failed: an element of array '$name' failed validation.$pathStr");
                    }
                }
            }
            for (var pair in this.primitiveFields.entries) {
                var name = pair.key;
                var type = pair.value;
                if (!value.containsKey(name)) {
                    errors.add("Validation failed: value missing field '$name'.$pathStr");
                }
                if (!type.check(value[name])) {
                    errors.add("Validation failed: field $name' has wrong value: '${value[name]}' should be '${type.toString()}'.$pathStr");
                }
            }
            for (var pair in this.predicateFields.entries) {
                var name = pair.key;
                var pred = pair.value;
                if (!value.containsKey(name)) {
                    errors.add("Validation failed: value missing field '$name'.$pathStr");
                }
                if (!pred(value[name])) {
                    errors.add("Validation failed: field '$name' failed to match predicate.$pathStr");
                }
            }
            for (var pair in this.objectFields.entries) {
                var name = pair.key;
                var subVal = pair.value;
                if (!value.containsKey(name)) {
                    errors.add("Validation failed: value missing field '$name'.$pathStr");
                }
                var (_, errs) = subVal._validateInternal(value[name], path.isNotEmpty ? "$path.$name" : name);
                errors.addAll(errs);
            }
            return (errors.isEmpty ? value as T : null, errors);
        }
        else {
            return (null, ["Validation failed: value was not a map.$pathStr"]);
        }
    }
}
