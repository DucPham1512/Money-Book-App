part of 'repository.dart';

// ----- Người ----------------------------------------------------------

extension PersonQueries on Repository {
  Stream<List<Person>> watchPeople({bool includeArchived = false}) {
    final q = db.select(db.people);
    if (!includeArchived) q.where((p) => p.isArchived.equals(false));
    q.orderBy([
      (p) => OrderingTerm(expression: p.sortOrder),
      (p) => OrderingTerm(expression: p.name),
    ]);
    return q.watch();
  }

  Future<int> insertPerson(PeopleCompanion p) => db.into(db.people).insert(p);

  Future<bool> updatePerson(Person p) => db.update(db.people).replace(p);

  Future<void> deletePerson(int id) =>
      (db.delete(db.people)..where((p) => p.id.equals(id))).go();

  Future<int> countTransactionsOfPerson(int personId) async {
    final t = db.transactions;
    final countExp = t.id.count();
    final q = db.selectOnly(t)
      ..addColumns([countExp])
      ..where(t.deletedAt.isNull() & t.personId.equals(personId));
    return (await q.getSingle()).read(countExp) ?? 0;
  }
}
