param(
    [Parameter(Mandatory = $false)]
    [string]$Path = "src/modules/PlayerBots/playerbot/TravelNode.cpp"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    throw "TravelNode.cpp not found: $Path"
}

$text = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")

function Replace-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $Old = $Old.Replace("`r`n", "`n")
    $New = $New.Replace("`r`n", "`n")

    $count = ([regex]::Matches($script:text, [regex]::Escape($Old))).Count
    if ($count -ne 1) {
        throw "Replacement '$Label' expected exactly once, found $count"
    }

    $script:text = $script:text.Replace($Old, $New)
}

Replace-Exact '#include "MotionGenerators/MoveMap.h"' @'
#include "playerbot/PerformanceMonitor.h"
#include "MotionGenerators/MoveMap.h"
'@ "include PerformanceMonitor"

Replace-Exact @'
TravelNodeRoute TravelNodeMap::getRoute(TravelNode* start, TravelNode* goal, Unit* unit)
{
    float unitSpeed = unit ? unit->GetSpeed(MOVE_RUN) : 7.0f;
'@ @'
TravelNodeRoute TravelNodeMap::getRoute(TravelNode* start, TravelNode* goal, Unit* unit)
{
    PlayerbotAI* perfAi = nullptr;
    if (Player* player = dynamic_cast<Player*>(unit))
        perfAi = player->GetPlayerbotAI();

    float unitSpeed = unit ? unit->GetSpeed(MOVE_RUN) : 7.0f;
'@ "node route perf ai"

Replace-Exact @'
    if(!start->hasRouteTo(goal))
        return TravelNodeRoute();

    //Basic A* algoritm
'@ @'
    bool hasRoute = false;
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoReachability;
        if (perfAi)
            pmoReachability = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoute::reachability", perfAi);
        hasRoute = start->hasRouteTo(goal);
    }

    if (!hasRoute)
        return TravelNodeRoute();

    std::unique_ptr<PerformanceMonitorOperation> pmoAStar;
    if (perfAi)
        pmoAStar = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoute::AStar", perfAi);

    //Basic A* algoritm
'@ "node route AStar"

Replace-Exact @'
TravelNodeRoute TravelNodeMap::getRoute(WorldPosition startPos, WorldPosition endPos, std::vector<WorldPosition>& startPath, std::vector<WorldPosition>& endPath, Unit* unit)
{
    if (m_nodes.empty())
'@ @'
TravelNodeRoute TravelNodeMap::getRoute(WorldPosition startPos, WorldPosition endPos, std::vector<WorldPosition>& startPath, std::vector<WorldPosition>& endPath, Unit* unit)
{
    PlayerbotAI* perfAi = nullptr;
    if (Player* player = dynamic_cast<Player*>(unit))
        perfAi = player->GetPlayerbotAI();

    if (m_nodes.empty())
'@ "position route perf ai"

Replace-Exact @'
    std::vector<WorldPosition> newStartPath;
    std::vector<TravelNode*> startNodes = getNodes(startPos, -1, transportEntry), endNodes = getNodes(endPos);
'@ @'
    std::vector<WorldPosition> newStartPath;
    std::vector<TravelNode*> startNodes, endNodes;
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoNodes;
        if (perfAi)
            pmoNodes = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::collect-nodes", perfAi);
        startNodes = getNodes(startPos, -1, transportEntry);
        endNodes = getNodes(endPos);
    }
'@ "collect candidate nodes"

Replace-Exact @'
    //Partial sort to get the closest 5 nodes at the begin of the array.        
    std::partial_sort(startNodes.begin(), startNodes.begin() + startNr, startNodes.end(), [startPos](TravelNode* i, TravelNode* j) {return i->getPosition()->sqDistance(startPos) < j->getPosition()->sqDistance(startPos); });
    startNodes.resize(startNr);
    std::partial_sort(endNodes.begin(), endNodes.begin() + endNr, endNodes.end(), [endPos](TravelNode* i, TravelNode* j) {return i->getPosition()->sqDistance(endPos) < j->getPosition()->sqDistance(endPos); });
    endNodes.resize(endNr);
'@ @'
    std::unique_ptr<PerformanceMonitorOperation> pmoSort;
    if (perfAi)
        pmoSort = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::sort-nodes", perfAi);

    //Partial sort to get the closest 5 nodes at the begin of the array.        
    std::partial_sort(startNodes.begin(), startNodes.begin() + startNr, startNodes.end(), [startPos](TravelNode* i, TravelNode* j) {return i->getPosition()->sqDistance(startPos) < j->getPosition()->sqDistance(startPos); });
    startNodes.resize(startNr);
    std::partial_sort(endNodes.begin(), endNodes.begin() + endNr, endNodes.end(), [endPos](TravelNode* i, TravelNode* j) {return i->getPosition()->sqDistance(endPos) < j->getPosition()->sqDistance(endPos); });
    endNodes.resize(endNr);

    pmoSort.reset();
'@ "sort candidate nodes"

Replace-Exact @'
            TravelNodeRoute route = getRoute(startNode, endNode, unit);
'@ @'
            TravelNodeRoute route;
            {
                std::unique_ptr<PerformanceMonitorOperation> pmoNodeRoute;
                if (perfAi)
                    pmoNodeRoute = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::node-AStar", perfAi);
                route = getRoute(startNode, endNode, unit);
            }
'@ "candidate node AStar"

Replace-Exact @'
                    endPath = endNodePosition.getPathTo(endPos, unit);
'@ @'
                    {
                        std::unique_ptr<PerformanceMonitorOperation> pmoEndConnector;
                        if (perfAi)
                            pmoEndConnector = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::end-connector", perfAi);
                        endPath = endNodePosition.getPathTo(endPos, unit);
                    }
'@ "end connector"

Replace-Exact @'
                            endPath = surfaceNode.getPathTo(surfaceEnd, unit);
'@ @'
                            {
                                std::unique_ptr<PerformanceMonitorOperation> pmoEndWater;
                                if (perfAi)
                                    pmoEndWater = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::end-connector-water", perfAi);
                                endPath = surfaceNode.getPathTo(surfaceEnd, unit);
                            }
'@ "end connector water"

Replace-Exact @'
                newStartPath = startPos.getPathTo(startNodePosition, unit);
'@ @'
                {
                    std::unique_ptr<PerformanceMonitorOperation> pmoStartConnector;
                    if (perfAi)
                        pmoStartConnector = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::start-connector", perfAi);
                    newStartPath = startPos.getPathTo(startNodePosition, unit);
                }
'@ "start connector"

Replace-Exact @'
                    newStartPath = surfaceStart.getPathTo(surfaceNode, unit);
'@ @'
                    {
                        std::unique_ptr<PerformanceMonitorOperation> pmoStartWater;
                        if (perfAi)
                            pmoStartWater = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::start-connector-water", perfAi);
                        newStartPath = surfaceStart.getPathTo(surfaceNode, unit);
                    }
'@ "start connector water"

Replace-Exact @'
TravelPath TravelNodeMap::getFullPath(WorldPosition startPos, WorldPosition endPos, Unit* unit)
{
    TravelPath movePath;
    std::vector<WorldPosition> beginPath, endPath;

    beginPath = endPos.getPathFromPath({ startPos }, unit, 40);

    if (endPos.isPathTo(beginPath,sPlayerbotAIConfig.spellDistance)) //If we can get within spell distance a longer route won't help.
        return TravelPath(beginPath);

    //[[Node pathfinding system]]
                //We try to find nodes near the bot and near the end position that have a route between them.
                //Then bot has to move towards/along the route.
    sTravelNodeMap.m_nMapMtx.lock_shared();

    //Find the route of nodes starting at a node closest to the start position and ending at a node closest to the endposition.
    //Also returns longPath: The path from the start position to the first node in the route.
    TravelNodeRoute route = sTravelNodeMap.getRoute(startPos, endPos, beginPath, endPath, unit);

    if (route.isEmpty())
    {
        route.cleanTempNodes();
        return movePath;
    }

    movePath = route.buildPath(beginPath, endPath);

    route.cleanTempNodes();

    sTravelNodeMap.m_nMapMtx.unlock_shared();

    return movePath;
}
'@ @'
TravelPath TravelNodeMap::getFullPath(WorldPosition startPos, WorldPosition endPos, Unit* unit)
{
    PlayerbotAI* perfAi = nullptr;
    if (Player* player = dynamic_cast<Player*>(unit))
        perfAi = player->GetPlayerbotAI();

    TravelPath movePath;
    std::vector<WorldPosition> beginPath, endPath;

    {
        std::unique_ptr<PerformanceMonitorOperation> pmoBeginPath;
        if (perfAi)
            pmoBeginPath = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeFull::begin-path", perfAi);
        beginPath = endPos.getPathFromPath({ startPos }, unit, 40);
    }

    if (endPos.isPathTo(beginPath,sPlayerbotAIConfig.spellDistance)) //If we can get within spell distance a longer route won't help.
        return TravelPath(beginPath);

    //[[Node pathfinding system]]
                //We try to find nodes near the bot and near the end position that have a route between them.
                //Then bot has to move towards/along the route.
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoLock;
        if (perfAi)
            pmoLock = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeFull::lock", perfAi);
        sTravelNodeMap.m_nMapMtx.lock_shared();
    }

    //Find the route of nodes starting at a node closest to the start position and ending at a node closest to the endposition.
    //Also returns longPath: The path from the start position to the first node in the route.
    TravelNodeRoute route;
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoRoute;
        if (perfAi)
            pmoRoute = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeFull::getRoute", perfAi);
        route = sTravelNodeMap.getRoute(startPos, endPos, beginPath, endPath, unit);
    }

    if (route.isEmpty())
    {
        route.cleanTempNodes();
        // The original code returned while still holding the shared lock.
        sTravelNodeMap.m_nMapMtx.unlock_shared();
        return movePath;
    }

    {
        std::unique_ptr<PerformanceMonitorOperation> pmoBuild;
        if (perfAi)
            pmoBuild = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeFull::buildPath", perfAi);
        movePath = route.buildPath(beginPath, endPath);
    }

    {
        std::unique_ptr<PerformanceMonitorOperation> pmoCleanup;
        if (perfAi)
            pmoCleanup = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeFull::cleanup-unlock", perfAi);
        route.cleanTempNodes();
        sTravelNodeMap.m_nMapMtx.unlock_shared();
    }

    return movePath;
}
'@ "getFullPath deep profiling and unlock fix"

[System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "TravelNode deep profiling instrumentation applied to $Path"
