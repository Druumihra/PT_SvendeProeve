/*
  Warnings:

  - The primary key for the `Friends` table will be changed. If it partially fails, the table could be left without primary key constraint.

*/
-- AlterTable
ALTER TABLE `Friends` DROP PRIMARY KEY,
    ADD PRIMARY KEY (`usersId`, `friendid`);
