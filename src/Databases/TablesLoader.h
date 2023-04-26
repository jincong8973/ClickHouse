#pragma once
#include <map>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <Core/QualifiedTableName.h>
#include <Core/Types.h>
#include <Databases/LoadingStrictnessLevel.h>
#include <Databases/TablesDependencyGraph.h>
#include <Interpreters/Context_fwd.h>
#include <Parsers/IAST_fwd.h>
#include <Common/Stopwatch.h>
#include <Common/AsyncLoader.h>

namespace Poco
{
    class Logger; // NOLINT(cppcoreguidelines-virtual-class-destructor)
}

class AtomicStopwatch;

namespace DB
{

void logAboutProgress(Poco::Logger * log, size_t processed, size_t total, AtomicStopwatch & watch);


class IDatabase;
using DatabasePtr = std::shared_ptr<IDatabase>;

struct ParsedTableMetadata
{
    String path;
    ASTPtr ast;
};

using ParsedMetadata = std::map<QualifiedTableName, ParsedTableMetadata>;

struct ParsedTablesMetadata
{
    String default_database;

    std::mutex mutex;
    ParsedMetadata parsed_tables;

    /// For logging
    size_t total_dictionaries = 0;
};

/// Loads tables (and dictionaries) from specified databases
/// taking into account dependencies between them.
class TablesLoader
{
public:
    using Databases = std::map<String, DatabasePtr>;

    TablesLoader(ContextMutablePtr global_context_, Databases databases_, LoadingStrictnessLevel strictness_mode_);
    TablesLoader() = delete;

    LoadTaskPtrs loadTablesAsync(LoadJobSet load_after = {});
    LoadTaskPtrs startupTablesAsync();
    void loadTables();
    void startupTables();

private:
    LoadTaskPtrs load_tables; // Tasks to load all tables
    LoadTaskPtrs startup_tables; // Tasks to startup all tables after loading

    ContextMutablePtr global_context;
    Databases databases;
    LoadingStrictnessLevel strictness_mode;

    Strings databases_to_load;
    ParsedTablesMetadata metadata;
    TablesDependencyGraph referential_dependencies;
    TablesDependencyGraph loading_dependencies;
    TablesDependencyGraph all_loading_dependencies;
    Poco::Logger * log;
    std::atomic<size_t> tables_processed{0};
    AtomicStopwatch stopwatch;

    AsyncLoader & async_loader;
    ThreadPool pool; // TODO(serxa): get rid of it

    void createTasks(LoadJobSet load_after);
    void buildDependencyGraph();
    void removeUnresolvableDependencies();
    void loadTablesInTopologicalOrder();
    void startLoadingTables(ContextMutablePtr load_context, const std::vector<StorageID> & tables_to_load, size_t level);
};

}
