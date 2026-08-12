import SwiftUI

/// What a resource is, which decides its badge.
enum ResourceKind: String, Codable, CaseIterable {
    case video = "V"
    case docs = "D"
    case article = "B"
    case practice = "P"
    case book = "K"

    var label: String {
        switch self {
        case .video: return "Video"
        case .docs: return "Docs"
        case .article: return "Article"
        case .practice: return "Practice"
        case .book: return "Book"
        }
    }

    var fill: Color {
        switch self {
        case .video: return Theme.orange100
        case .practice: return Theme.accent200
        case .book: return .clear
        case .article, .docs: return Theme.neutral200
        }
    }

    var tint: Color {
        switch self {
        case .video: return Theme.orange700
        case .practice: return Theme.accent700
        case .book: return Theme.neutral700
        case .article, .docs: return Theme.neutral700
        }
    }

    /// Only "Book" is outlined rather than filled, so the five kinds stay
    /// distinguishable without inventing a fifth colour.
    var outlined: Bool { self == .book }
}

struct RoadmapResource: Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let kind: ResourceKind
    let track: String
    let topic: String
    let phase: Int
}

/// Every link in the roadmap, grouped the way the roadmap itself groups them:
/// phase → topic. The track on each topic is what the Library's track chips
/// filter by.
///
/// `id` is positional — "p{phase}.t{topic}.r{resource}" — and is the key under
/// which "read" state is stored on disk. Rows may be appended, never reordered.
enum RoadmapLibrary {

    static let all: [RoadmapResource] = {
        var out: [RoadmapResource] = []
        var topicIndexByPhase: [Int: Int] = [:]
        for raw in rawTopics {
            let topicIndex = topicIndexByPhase[raw.phase, default: 0]
            topicIndexByPhase[raw.phase] = topicIndex + 1
            for (linkIndex, link) in raw.links.enumerated() {
                out.append(RoadmapResource(
                    id: "p\(raw.phase).t\(topicIndex).r\(linkIndex)",
                    title: link[0],
                    url: link[1],
                    kind: ResourceKind(rawValue: link[2]) ?? .article,
                    track: raw.track,
                    topic: raw.topic,
                    phase: raw.phase
                ))
            }
        }
        return out
    }()

    // MARK: - Source table

    private struct RawTopic {
        let phase: Int
        let topic: String
        let track: String
        /// [title, url, kind]
        let links: [[String]]
    }

    private static let rawTopics: [RawTopic] = [
        // MARK: Phase 1 — Go foundations · SQL foundations
        RawTopic(phase: 1, topic: "Go basics", track: "Go", links: [
            ["A Tour of Go — do every exercise", "https://go.dev/tour/welcome/1", "P"],
            ["Go by Example — the reference you will reopen weekly", "https://gobyexample.com/", "B"],
            ["Effective Go", "https://go.dev/doc/effective_go", "D"],
            ["Go Slices: usage and internals", "https://go.dev/blog/slices-intro", "B"],
            ["JustForFunc — Francesc Campoy on Go", "https://www.youtube.com/c/JustForFunc", "V"],
            ["The Go Programming Language channel", "https://www.youtube.com/@golang", "V"],
        ]),
        RawTopic(phase: 1, topic: "Types & interfaces", track: "Go", links: [
            ["Go FAQ — the design rationale section", "https://go.dev/doc/faq", "D"],
            ["An Introduction to Generics", "https://go.dev/blog/intro-generics", "B"],
            ["Uber Go Style Guide", "https://github.com/uber-go/guide/blob/master/style.md", "B"],
            ["100 Go Mistakes and How to Avoid Them", "https://100go.co/", "K"],
            ["Go Wiki: Code Review Comments", "https://go.dev/wiki/CodeReviewComments", "D"],
        ]),
        RawTopic(phase: 1, topic: "Errors, modules, testing", track: "Go", links: [
            ["Working with Errors in Go 1.13", "https://go.dev/blog/go1.13-errors", "B"],
            ["Go Modules Reference", "https://go.dev/ref/mod", "D"],
            ["Testing package docs", "https://pkg.go.dev/testing", "D"],
            ["golangci-lint", "https://golangci-lint.run/", "D"],
            ["Learn Go with Tests — TDD-first Go course", "https://quii.gitbook.io/learn-go-with-tests", "P"],
        ]),
        RawTopic(phase: 1, topic: "SQL foundations", track: "Databases", links: [
            ["PostgreSQL Tutorial — official", "https://www.postgresql.org/docs/current/tutorial.html", "D"],
            ["PG Exercises — 80+ graded SQL problems", "https://pgexercises.com/", "P"],
            ["Modern SQL — window functions, CTEs, and more", "https://modern-sql.com/", "B"],
            ["SQL Data Types you should not use", "https://wiki.postgresql.org/wiki/Don%27t_Do_This", "B"],
            ["Hussein Nasser — Postgres playlist", "https://www.youtube.com/playlist?list=PLQnljOFTspQWGrOqslniFlRcwxyY94cjj", "V"],
            ["SQLBolt — quick interactive drills", "https://sqlbolt.com/", "P"],
        ]),
        RawTopic(phase: 1, topic: "Ship v0", track: "Project", links: [
            ["Standard Go Project Layout", "https://github.com/golang-standards/project-layout", "B"],
            ["cobra — CLI framework", "https://github.com/spf13/cobra", "D"],
            ["Temporal — read how a real workflow engine models this", "https://docs.temporal.io/", "D"],
        ]),

        // MARK: Phase 2 — Go concurrency · Transactions and MVCC
        RawTopic(phase: 2, topic: "Goroutines & channels", track: "Go", links: [
            ["Go Concurrency Patterns — Rob Pike", "https://www.youtube.com/watch?v=f6kdp27TYZs", "V"],
            ["Advanced Go Concurrency Patterns — Sameer Ajmani", "https://www.youtube.com/watch?v=QDDwwePbDtw", "V"],
            ["Go Concurrency Patterns: Pipelines and cancellation", "https://go.dev/blog/pipelines", "B"],
            ["Go by Example — Goroutines onward", "https://gobyexample.com/goroutines", "P"],
            ["Concurrency in Go (Katherine Cox-Buday)", "https://www.oreilly.com/library/view/concurrency-in-go/9781491941294/", "K"],
        ]),
        RawTopic(phase: 2, topic: "Context & sync", track: "Go", links: [
            ["Go Concurrency Patterns: Context", "https://go.dev/blog/context", "B"],
            ["The Go Memory Model", "https://go.dev/ref/mem", "D"],
            ["Data Race Detector", "https://go.dev/doc/articles/race_detector", "D"],
            ["errgroup package", "https://pkg.go.dev/golang.org/x/sync/errgroup", "D"],
            ["100 Go Mistakes — concurrency chapters", "https://100go.co/", "K"],
        ]),
        RawTopic(phase: 2, topic: "Transactions & isolation", track: "Databases", links: [
            ["PostgreSQL — Transaction Isolation", "https://www.postgresql.org/docs/current/transaction-iso.html", "D"],
            ["A Critique of ANSI SQL Isolation Levels (Berenson et al.)", "https://arxiv.org/abs/cs/0701157", "K"],
            ["Jepsen — Consistency Models", "https://jepsen.io/consistency", "B"],
            ["Hussein Nasser — Database Engineering playlist", "https://www.youtube.com/playlist?list=PLQnljOFTspQXjD0HOzN7P2tgzu7scWpl2", "V"],
            ["DDIA chapter 7 — Transactions", "https://dataintensive.net/", "K"],
        ]),
        RawTopic(phase: 2, topic: "MVCC & locking", track: "Databases", links: [
            ["PostgreSQL — Concurrency Control (MVCC)", "https://www.postgresql.org/docs/current/mvcc.html", "D"],
            ["PostgreSQL — Explicit Locking", "https://www.postgresql.org/docs/current/explicit-locking.html", "D"],
            ["pglocks.org — which locks conflict with which", "https://pglocks.org/", "P"],
            ["Routine Vacuuming and XID wraparound", "https://www.postgresql.org/docs/current/routine-vacuuming.html", "D"],
            ["Postgres.fm — podcast, one topic per episode", "https://postgres.fm/", "V"],
            ["Microservices.io — Saga pattern", "https://microservices.io/patterns/data/saga.html", "B"],
        ]),
        RawTopic(phase: 2, topic: "Ship v1", track: "Project", links: [
            ["Exponential Backoff And Jitter — AWS", "https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/", "B"],
            ["River — a Postgres job queue in Go, read the source", "https://github.com/riverqueue/river", "P"],
            ["pgx — the Postgres driver you should use", "https://github.com/jackc/pgx", "D"],
        ]),

        // MARK: Phase 3 — Production services · Migrations
        RawTopic(phase: 3, topic: "HTTP services", track: "Go", links: [
            ["How I write HTTP services in Go — Mat Ryer", "https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/", "B"],
            ["The complete guide to Go net/http timeouts", "https://blog.cloudflare.com/the-complete-guide-to-golang-net-http-timeouts/", "B"],
            ["chi router", "https://github.com/go-chi/chi", "D"],
            ["log/slog package docs", "https://pkg.go.dev/log/slog", "D"],
        ]),
        RawTopic(phase: 3, topic: "Data layer", track: "Databases", links: [
            ["sqlc — compile SQL into type-safe Go", "https://docs.sqlc.dev/", "D"],
            ["pgx documentation", "https://pkg.go.dev/github.com/jackc/pgx/v5", "D"],
            ["Organising Database Access in Go", "https://www.alexedwards.net/blog/organising-database-access", "B"],
        ]),
        RawTopic(phase: 3, topic: "Migrations", track: "Databases", links: [
            ["golang-migrate", "https://github.com/golang-migrate/migrate", "D"],
            ["Atlas — schema as code, with lint for unsafe changes", "https://atlasgo.io/", "D"],
            ["ParallelChange (expand–contract) — Martin Fowler", "https://martinfowler.com/bliki/ParallelChange.html", "B"],
            ["Testcontainers for Go", "https://golang.testcontainers.org/", "P"],
        ]),
        RawTopic(phase: 3, topic: "Dangerous DDL", track: "Databases", links: [
            ["strong_migrations — the canonical unsafe-migration list", "https://github.com/ankane/strong_migrations", "B"],
            ["PostgreSQL — ALTER TABLE and its lock levels", "https://www.postgresql.org/docs/current/sql-altertable.html", "D"],
            ["pglocks.org", "https://pglocks.org/", "P"],
            ["pg_repack", "https://github.com/reorg/pg_repack", "D"],
            ["gh-ost — online schema migration for MySQL", "https://github.com/github/gh-ost", "D"],
        ]),
        RawTopic(phase: 3, topic: "gRPC", track: "Go", links: [
            ["gRPC Go quick start", "https://grpc.io/docs/languages/go/quickstart/", "D"],
            ["Protocol Buffers language guide", "https://protobuf.dev/programming-guides/proto3/", "D"],
            ["Buf — modern protobuf tooling", "https://buf.build/docs/introduction", "D"],
        ]),
        RawTopic(phase: 3, topic: "Ship v2", track: "Project", links: [
            ["Zero-downtime Postgres migrations — a checklist", "https://github.com/ankane/strong_migrations", "B"],
        ]),

        // MARK: Phase 4 — Kubernetes core · Query performance
        RawTopic(phase: 4, topic: "K8s workloads", track: "Kubernetes", links: [
            ["Kubernetes Concepts — the official docs", "https://kubernetes.io/docs/concepts/", "D"],
            ["TechWorld with Nana — Kubernetes crash course", "https://www.youtube.com/@TechWorldwithNana", "V"],
            ["kind — run a cluster on your laptop", "https://kind.sigs.k8s.io/", "P"],
            ["Learnk8s — deep-dive articles", "https://learnk8s.io/articles", "B"],
            ["KodeKloud — lab-first K8s courses", "https://www.youtube.com/@KodeKloud", "V"],
        ]),
        RawTopic(phase: 4, topic: "Scheduling", track: "Kubernetes", links: [
            ["Kubernetes Scheduler docs", "https://kubernetes.io/docs/concepts/scheduling-eviction/", "D"],
            ["Setting the right requests and limits — Learnk8s", "https://learnk8s.io/setting-cpu-memory-limits-requests", "B"],
            ["KEDA — event-driven autoscaling", "https://keda.sh/docs/latest/concepts/", "D"],
        ]),
        RawTopic(phase: 4, topic: "Indexes", track: "Databases", links: [
            ["Use The Index, Luke — the best free SQL indexing book", "https://use-the-index-luke.com/", "K"],
            ["PostgreSQL — Indexes", "https://www.postgresql.org/docs/current/indexes.html", "D"],
            ["PostgreSQL — Index-only scans", "https://www.postgresql.org/docs/current/indexes-index-only-scans.html", "D"],
            ["Hussein Nasser — Database Engineering playlist", "https://www.youtube.com/playlist?list=PLQnljOFTspQXjD0HOzN7P2tgzu7scWpl2", "V"],
        ]),
        RawTopic(phase: 4, topic: "Planning & pooling", track: "Databases", links: [
            ["PostgreSQL — Using EXPLAIN", "https://www.postgresql.org/docs/current/using-explain.html", "D"],
            ["explain.dalibo.com — visualise a query plan", "https://explain.dalibo.com/", "P"],
            ["pg_stat_statements", "https://www.postgresql.org/docs/current/pgstatstatements.html", "D"],
            ["PgBouncer documentation", "https://www.pgbouncer.org/usage.html", "D"],
            ["PGTune — sane starting configuration", "https://pgtune.leopard.in.ua/", "P"],
        ]),
        RawTopic(phase: 4, topic: "Ship v3", track: "Project", links: [
            ["k6 — load testing", "https://grafana.com/docs/k6/latest/", "D"],
            ["NeetCode roadmap", "https://neetcode.io/roadmap", "P"],
        ]),

        // MARK: Phase 5 — CKA · Redis and caching
        RawTopic(phase: 5, topic: "K8s networking", track: "Kubernetes", links: [
            ["Kubernetes networking concepts", "https://kubernetes.io/docs/concepts/services-networking/", "D"],
            ["Network Policy Editor — build policies visually", "https://editor.networkpolicy.io/", "P"],
            ["Cilium docs — eBPF networking", "https://docs.cilium.io/en/stable/overview/intro/", "D"],
            ["CNCF channel — KubeCon talks", "https://www.youtube.com/@cncf", "V"],
        ]),
        RawTopic(phase: 5, topic: "Storage & cluster admin", track: "Kubernetes", links: [
            ["Kubernetes The Hard Way — Kelsey Hightower", "https://github.com/kelseyhightower/kubernetes-the-hard-way", "P"],
            ["kubeadm cluster upgrade", "https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/", "D"],
            ["Backing up an etcd cluster", "https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/", "D"],
            ["Helm docs", "https://helm.sh/docs/", "D"],
            ["Kustomize", "https://kubectl.docs.kubernetes.io/references/kustomize/", "D"],
        ]),
        RawTopic(phase: 5, topic: "Troubleshooting (30%)", track: "Kubernetes", links: [
            ["Troubleshooting Applications — official", "https://kubernetes.io/docs/tasks/debug/debug-application/", "D"],
            ["A visual guide to troubleshooting deployments", "https://learnk8s.io/troubleshooting-deployments", "B"],
            ["Debugging DNS resolution", "https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/", "D"],
            ["crictl user guide", "https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/", "D"],
        ]),
        RawTopic(phase: 5, topic: "CKA exam", track: "Kubernetes", links: [
            ["CNCF curriculum — the authoritative topic list", "https://github.com/cncf/curriculum", "D"],
            ["CKA exam registration — Linux Foundation", "https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/", "D"],
            ["killer.sh — the simulator included with your exam", "https://killer.sh/", "P"],
            ["kubectl Cheat Sheet", "https://kubernetes.io/docs/reference/kubectl/quick-reference/", "D"],
            ["KodeKloud — CKA course and labs", "https://www.youtube.com/@KodeKloud", "V"],
        ]),
        RawTopic(phase: 5, topic: "Redis & caching", track: "Databases", links: [
            ["Redis data types", "https://redis.io/docs/latest/develop/data-types/", "D"],
            ["Distributed locks with Redis", "https://redis.io/docs/latest/develop/use/patterns/distributed-locks/", "D"],
            ["How to do distributed locking — Martin Kleppmann", "https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html", "B"],
            ["Redis key eviction policies", "https://redis.io/docs/latest/develop/reference/eviction/", "D"],
            ["Try Redis — interactive", "https://try.redis.io/", "P"],
        ]),
        RawTopic(phase: 5, topic: "Ship v4", track: "Project", links: [
            ["Caching Challenges and Strategies — AWS", "https://aws.amazon.com/builders-library/caching-challenges-and-strategies/", "B"],
        ]),

        // MARK: Phase 6 — Kafka · Replication and sharding
        RawTopic(phase: 6, topic: "Kafka core", track: "Streaming", links: [
            ["Apache Kafka documentation", "https://kafka.apache.org/documentation/", "D"],
            ["Confluent Developer — free structured courses", "https://developer.confluent.io/courses/", "P"],
            ["The Log: what every engineer should know — Jay Kreps", "https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying", "B"],
            ["Confluent YouTube channel", "https://www.youtube.com/@Confluent", "V"],
            ["Kafka: The Definitive Guide (free from Confluent)", "https://www.confluent.io/resources/kafka-the-definitive-guide-v2/", "K"],
        ]),
        RawTopic(phase: 6, topic: "Delivery & outbox", track: "Streaming", links: [
            ["Transactional Outbox pattern", "https://microservices.io/patterns/data/transactional-outbox.html", "B"],
            ["Exactly-once semantics in Kafka — Confluent", "https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/", "B"],
            ["Schema Registry concepts", "https://docs.confluent.io/platform/current/schema-registry/index.html", "D"],
            ["Idempotency — Stripe API design", "https://docs.stripe.com/api/idempotent_requests", "B"],
        ]),
        RawTopic(phase: 6, topic: "PG replication", track: "Databases", links: [
            ["PostgreSQL — High Availability and Replication", "https://www.postgresql.org/docs/current/high-availability.html", "D"],
            ["Logical replication", "https://www.postgresql.org/docs/current/logical-replication.html", "D"],
            ["DDIA chapter 5 — Replication", "https://dataintensive.net/", "K"],
        ]),
        RawTopic(phase: 6, topic: "Partitioning & sharding", track: "Databases", links: [
            ["PostgreSQL — Table Partitioning", "https://www.postgresql.org/docs/current/ddl-partitioning.html", "D"],
            ["pg_partman — partition maintenance", "https://github.com/pgpartman/pg_partman", "D"],
            ["Citus — distributed Postgres", "https://docs.citusdata.com/en/stable/", "D"],
            ["Debezium documentation", "https://debezium.io/documentation/reference/stable/index.html", "D"],
            ["How Discord stores trillions of messages", "https://discord.com/blog/how-discord-stores-trillions-of-messages", "B"],
        ]),
        RawTopic(phase: 6, topic: "Ship v5", track: "Project", links: [
            ["franz-go — a good Kafka client for Go", "https://github.com/twmb/franz-go", "D"],
        ]),

        // MARK: Phase 7 — Observability · Backups and HA
        RawTopic(phase: 7, topic: "Metrics & tracing", track: "System Design", links: [
            ["Prometheus documentation", "https://prometheus.io/docs/introduction/overview/", "D"],
            ["PromLabs — PromQL tutorials", "https://promlabs.com/promql-cheat-sheet/", "B"],
            ["OpenTelemetry Go", "https://opentelemetry.io/docs/languages/go/", "D"],
            ["Google SRE Book — free online", "https://sre.google/sre-book/table-of-contents/", "K"],
            ["The SRE Workbook — SLO chapters", "https://sre.google/workbook/implementing-slos/", "K"],
        ]),
        RawTopic(phase: 7, topic: "Nginx", track: "System Design", links: [
            ["nginx documentation", "https://nginx.org/en/docs/", "D"],
            ["NGINX Admin Guide", "https://docs.nginx.com/nginx/admin-guide/", "D"],
            ["Mozilla SSL Configuration Generator", "https://ssl-config.mozilla.org/", "P"],
            ["Hussein Nasser — proxies and load balancing playlist", "https://www.youtube.com/playlist?list=PLQnljOFTspQVMeBmWI2AhxULWEeo7AaMC", "V"],
        ]),
        RawTopic(phase: 7, topic: "Backups & failover", track: "Databases", links: [
            ["PostgreSQL — Backup and Restore", "https://www.postgresql.org/docs/current/backup.html", "D"],
            ["Continuous archiving and PITR", "https://www.postgresql.org/docs/current/continuous-archiving.html", "D"],
            ["pgBackRest", "https://pgbackrest.org/user-guide.html", "D"],
            ["Patroni documentation", "https://patroni.readthedocs.io/en/latest/", "D"],
        ]),
        RawTopic(phase: 7, topic: "GitOps & chaos", track: "Kubernetes", links: [
            ["Argo CD documentation", "https://argo-cd.readthedocs.io/en/stable/", "D"],
            ["Argo Rollouts — canary and blue-green", "https://argo-rollouts.readthedocs.io/en/stable/", "D"],
            ["Kyverno policies", "https://kyverno.io/docs/", "D"],
            ["Principles of Chaos Engineering", "https://principlesofchaos.org/", "B"],
            ["DevOps Toolkit — platform engineering deep dives", "https://www.youtube.com/@DevOpsToolkit", "V"],
        ]),
        RawTopic(phase: 7, topic: "Ship v6", track: "Project", links: [
            ["The Four Golden Signals — SRE Book", "https://sre.google/sre-book/monitoring-distributed-systems/", "K"],
        ]),

        // MARK: Phase 8 — Operators · Data breadth
        RawTopic(phase: 8, topic: "client-go", track: "Kubernetes", links: [
            ["client-go examples", "https://github.com/kubernetes/client-go/tree/master/examples", "P"],
            ["sample-controller — the canonical starting point", "https://github.com/kubernetes/sample-controller", "P"],
            ["Kubernetes API concepts", "https://kubernetes.io/docs/reference/using-api/api-concepts/", "D"],
        ]),
        RawTopic(phase: 8, topic: "Operators & CRDs", track: "Kubernetes", links: [
            ["The Kubebuilder Book", "https://book.kubebuilder.io/", "K"],
            ["Operator SDK", "https://sdk.operatorframework.io/docs/", "D"],
            ["Programming Kubernetes (concepts online)", "https://kubernetes.io/docs/concepts/extend-kubernetes/operator/", "D"],
            ["Admission webhooks", "https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/", "D"],
        ]),
        RawTopic(phase: 8, topic: "Storage internals", track: "Databases", links: [
            ["Database Internals — Alex Petrov", "https://www.databass.dev/", "K"],
            ["CMU Database Systems — full lecture series", "https://www.youtube.com/@CMUDatabaseGroup", "V"],
            ["RocksDB wiki — compaction in practice", "https://github.com/facebook/rocksdb/wiki", "D"],
        ]),
        RawTopic(phase: 8, topic: "NoSQL breadth", track: "Databases", links: [
            ["DynamoDB single-table design — Alex DeBrie", "https://www.alexdebrie.com/posts/dynamodb-single-table/", "B"],
            ["Cassandra data modelling", "https://cassandra.apache.org/doc/latest/cassandra/developing/data-modeling/index.html", "D"],
            ["Elasticsearch guide", "https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html", "D"],
            ["ClickHouse documentation", "https://clickhouse.com/docs", "D"],
            ["Dynamo paper — the original", "https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf", "K"],
        ]),
        RawTopic(phase: 8, topic: "Ship v7", track: "Project", links: [
            ["Argo Workflows — read how they modelled the CRD", "https://argo-workflows.readthedocs.io/en/latest/", "P"],
            ["CKS certification", "https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/", "D"],
        ]),

        // MARK: Phase 9 — Kotlin & JVM · Design mastery
        RawTopic(phase: 9, topic: "Kotlin language", track: "Kotlin/JVM", links: [
            ["Kotlin docs — start here", "https://kotlinlang.org/docs/home.html", "D"],
            ["Kotlin by Example", "https://play.kotlinlang.org/byExample/overview", "P"],
            ["Kotlin Koans — interactive exercises", "https://play.kotlinlang.org/koans/overview", "P"],
            ["Kotlin by JetBrains — YouTube", "https://www.youtube.com/@Kotlin", "V"],
        ]),
        RawTopic(phase: 9, topic: "Coroutines & Flow", track: "Kotlin/JVM", links: [
            ["Coroutines guide", "https://kotlinlang.org/docs/coroutines-guide.html", "D"],
            ["Structured concurrency — Roman Elizarov", "https://elizarov.medium.com/structured-concurrency-722d765aa952", "B"],
            ["Asynchronous Flow", "https://kotlinlang.org/docs/flow.html", "D"],
        ]),
        RawTopic(phase: 9, topic: "Spring Boot & JPA", track: "Kotlin/JVM", links: [
            ["Spring Boot reference", "https://docs.spring.io/spring-boot/index.html", "D"],
            ["Spring guides — short practical tutorials", "https://spring.io/guides", "P"],
            ["Vlad Mihalcea — the JPA and Hibernate reference blog", "https://vladmihalcea.com/tutorials/hibernate/", "B"],
            ["Testcontainers for Java", "https://java.testcontainers.org/", "P"],
        ]),
        RawTopic(phase: 9, topic: "Design mastery", track: "System Design", links: [
            ["System Design Primer", "https://github.com/donnemartin/system-design-primer", "K"],
            ["ByteByteGo — YouTube", "https://www.youtube.com/@ByteByteGo", "V"],
            ["Asli Engineering — Arpit Bhayani", "https://www.youtube.com/@AsliEngineering", "V"],
            ["Agoda Engineering blog", "https://medium.com/agoda-engineering", "B"],
            ["Booking.com tech blog", "https://blog.booking.com/", "B"],
            ["Atlassian Engineering blog", "https://www.atlassian.com/engineering", "B"],
        ]),
        RawTopic(phase: 9, topic: "Resume & stories", track: "Visibility", links: [
            ["Levels.fyi — compensation data", "https://www.levels.fyi/", "P"],
            ["Agoda — how we hire", "https://careersatagoda.com/blog/how-we-hire-agodas-tech-team-interview-process/", "B"],
            ["STAR method explained", "https://www.themuse.com/advice/star-interview-method", "B"],
        ]),
        RawTopic(phase: 9, topic: "Ship v8", track: "Project", links: []),

        // MARK: Phase 10 — Interview mode
        RawTopic(phase: 10, topic: "Applications & referrals", track: "Visibility", links: [
            ["Agoda careers", "https://careersatagoda.com/", "P"],
            ["Booking.com careers", "https://careers.booking.com/", "P"],
            ["Atlassian careers", "https://www.atlassian.com/company/careers", "P"],
            ["Intuit careers", "https://jobs.intuit.com/", "P"],
        ]),
        RawTopic(phase: 10, topic: "Mocks & drilling", track: "DSA", links: [
            ["NeetCode — problem walkthroughs", "https://www.youtube.com/@NeetCode", "V"],
            ["NeetCode roadmap", "https://neetcode.io/roadmap", "P"],
            ["Pramp — free peer mock interviews", "https://www.pramp.com/", "P"],
            ["Hello Interview — system design practice", "https://www.hellointerview.com/", "P"],
        ]),
        RawTopic(phase: 10, topic: "Loops", track: "Visibility", links: []),
        RawTopic(phase: 10, topic: "Offers & decision", track: "Visibility", links: [
            ["Ten Rules for Negotiating a Job Offer", "https://haseebq.com/my-ten-rules-for-negotiating-a-job-offer/", "B"],
            ["Levels.fyi", "https://www.levels.fyi/", "P"],
        ]),
    ]
}
