-- Фикс 4: политика friendships_own не позволяла ПРИНЯТЬ заявку:
-- with check (requested_by = auth.uid()) блокировал update второй стороной.
-- Разделяем на select/insert/update/delete.

drop policy if exists friendships_own on public.friendships;

create policy friendships_select on public.friendships
  for select using (auth.uid() in (user_a, user_b));

-- Отправить заявку: только от себя, только pending, только в свою пару.
create policy friendships_insert on public.friendships
  for insert with check (
    auth.uid() = requested_by
    and auth.uid() in (user_a, user_b)
    and status = 'pending');

-- Принять может только вторая сторона (не автор заявки).
create policy friendships_accept on public.friendships
  for update
  using (auth.uid() in (user_a, user_b) and auth.uid() <> requested_by)
  with check (status = 'accepted');

-- Отклонить/отменить/удалить из друзей может любая из сторон.
create policy friendships_delete on public.friendships
  for delete using (auth.uid() in (user_a, user_b));
