-- +goose Up
create view groups as
select distinct json_each.value grp
from contacts c, json_each(c.groups)
where c.groups is not null
  and json_each.value is not null;

create view contact_groups as
select c.id            as contact_id,
       json_each.value as grp
from contacts c, json_each(c.groups)
where c.groups is not null
  and json_each.value is not null;

-- +goose Down
drop view groups;
drop view contact_groups;
