import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  const alice = await prisma.educationLevel.createMany({
    data: [
      {
        code: "secondary",
        name: "Среднее",
      },
      {
        code: "special_secondary",
        name: "Среднее специальное",
      },
      {
        code: "unfinished_higher",
        name: "Неоконченное высшее",
      },
      {
        code: "higher",
        name: "Высшее",
      },
      {
        code: "bachelor",
        name: "Бакалавр",
      },
      {
        code: "master",
        name: "Магистр",
      },
      {
        code: "candidate",
        name: "Кандидат наук",
      },
      {
        code: "doctor",
        name: "Доктор наук",
      },
    ],
    skipDuplicates: true,
  });
}
main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
