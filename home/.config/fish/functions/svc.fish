function svc --description 'Manage the dev services stack in ~/services'
    set -l dir ~/services
    set -l cmd $argv[1]
    set -e argv[1]

    # short names -> compose profiles
    set -l profiles
    for a in $argv
        switch $a
            case pg postgres postgresql
                set -a profiles --profile pg
            case redis mongo kafka telegram kafka-ui pgadmin redisinsight phpmyadmin mongo-express
                set -a profiles --profile $a
            case mysql mariadb
                set -a profiles --profile mariadb
            case ui
                set -a profiles --profile pgadmin --profile redisinsight --profile phpmyadmin --profile mongo-express --profile kafka-ui
            case all
                set -a profiles --profile pg --profile redis --profile mongo --profile mariadb --profile kafka --profile kafka-ui --profile pgadmin --profile redisinsight --profile phpmyadmin --profile mongo-express
        end
    end

    switch $cmd
        case up
            docker compose --project-directory $dir $profiles up -d --wait
        case down
            if test (count $profiles) -eq 0
                docker compose --project-directory $dir --profile pg --profile redis --profile mongo --profile mariadb --profile kafka --profile kafka-ui --profile pgadmin --profile redisinsight --profile phpmyadmin --profile mongo-express --profile telegram down
            else
                docker compose --project-directory $dir $profiles stop
                docker compose --project-directory $dir $profiles rm -f
            end
        case ps ls
            docker compose --project-directory $dir ps
        case logs
            docker compose --project-directory $dir $profiles logs -f --tail 100
        case psql
            docker compose --project-directory $dir exec postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
        case redis-cli
            docker compose --project-directory $dir exec redis sh -c 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning'
        case '*'
            echo "usage: svc up|down|ps|logs|psql|redis-cli [pg redis mongo mariadb kafka telegram | pgadmin redisinsight phpmyadmin mongo-express kafka-ui | ui all]"
            return 1
    end
end
