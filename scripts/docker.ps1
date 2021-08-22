docker run -dp 80:3000 `
   -e VTT_DBUSER="dbadmin@dev-todo-psqlserver" `
   -e VTT_DBPASSWORD="Password1" `
   -e VTT_DBNAME="tododb" `
   -e VTT_DBPORT=5432 `
   -e VTT_DBHOST="dev-todo-psqlserver.postgres.database.azure.com" `
   -e VTT_LISTENHOST=0.0.0.0 `
   -e VTT_LISTENPORT=3000 `
servian/techchallengeapp:latest `
   serve


./TechChallengeApp serve