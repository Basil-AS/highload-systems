from hashlib import sha3_256

study_group = "211-331"  # Укажите номер учебной группы
fullname = "Скрыпник Василий Александрович"  # Указаны ФИО
suffix = "Высоконагруженные системы. Лабораторная работа 1"

string_for_hash = f"{study_group} {fullname} {suffix}"
var_total = 3
variant = int(sha3_256(string_for_hash.encode('utf-8')).hexdigest(), 16) % var_total + 1
print(f"Ваш вариант: {variant}")