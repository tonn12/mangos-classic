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

# getRoute(WorldPosition...) only needs the five nearest candidates. getNodes()
# sorts every TravelNode on the map and the caller immediately partial_sorts again.
# Preserve the same candidate set but defer ordering to the existing partial_sort.
Replace-Exact @'
    std::vector<TravelNode*> startNodes, endNodes;
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoNodes;
        if (perfAi)
            pmoNodes = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::collect-nodes", perfAi);
        startNodes = getNodes(startPos, -1, transportEntry);
        endNodes = getNodes(endPos);
    }
'@ @'
    std::vector<TravelNode*> startNodes, endNodes;
    {
        std::unique_ptr<PerformanceMonitorOperation> pmoNodes;
        if (perfAi)
            pmoNodes = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::collect-nodes", perfAi);

        for (TravelNode* node : m_map_nodes[startPos.getMapId()])
        {
            if (transportEntry && node->getTransportId() != transportEntry)
                continue;
            startNodes.push_back(node);
        }

        for (TravelNode* node : m_map_nodes[endPos.getMapId()])
            endNodes.push_back(node);
    }
'@ "avoid full getNodes sorts"

# The A* open list originally sorts the full vector every iteration. The previous
# diagnostic optimization used min_element(), which reduced O(n log n) to O(n)
# but still scans the entire open set for every expanded node. Use a real min-heap
# instead. When an already-open node receives a lower cost, rebuild the heap to
# preserve the original decrease-key semantics without changing route costs.
Replace-Exact @'
    std::vector<TravelNodeStub*> open, closed;
'@ @'
    std::vector<TravelNodeStub*> open;
'@ "remove unused closed vector"

Replace-Exact @'
    std::make_heap(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });

    open.push_back(startStub);
    std::push_heap(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });
    startStub->open = true;

    while (!open.empty())
    {
        std::sort(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });

        currentNode = open.front(); // pop n node from open for which f is minimal

        std::pop_heap(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });
        open.pop_back();
'@ @'
    auto openCmp = [](TravelNodeStub* i, TravelNodeStub* j) { return i->m_f > j->m_f; };
    std::make_heap(open.begin(), open.end(), openCmp);

    open.push_back(startStub);
    std::push_heap(open.begin(), open.end(), openCmp);
    startStub->open = true;

    while (!open.empty())
    {
        std::pop_heap(open.begin(), open.end(), openCmp);
        currentNode = open.back(); // pop node from open for which f is minimal
        open.pop_back();
'@ "replace AStar open scan with min-heap"

Replace-Exact @'
        currentNode->close = true;
        closed.push_back(currentNode);
'@ @'
        currentNode->close = true;
'@ "remove unused closed tracking"

# Avoid constructing a TravelNodeStub for every visited edge when the node already
# exists in the unordered_map. Most A* edge relaxations revisit existing nodes.
Replace-Exact @'
            childNode = &m_stubs.insert(std::make_pair(linkNode, TravelNodeStub(linkNode))).first->second;
'@ @'
            auto stubIt = m_stubs.find(linkNode);
            if (stubIt == m_stubs.end())
                stubIt = m_stubs.emplace(linkNode, TravelNodeStub(linkNode)).first;
            childNode = &stubIt->second;
'@ "avoid redundant TravelNodeStub construction"

Replace-Exact @'
            if (childNode->close)
                childNode->close = false;
            if (!childNode->open)
            {
                open.push_back(childNode);
                std::push_heap(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });
                childNode->open = true;
            }
'@ @'
            if (childNode->close)
                childNode->close = false;
            if (!childNode->open)
            {
                open.push_back(childNode);
                std::push_heap(open.begin(), open.end(), openCmp);
                childNode->open = true;
            }
            else
            {
                // m_f decreased for a node already in the heap. std::heap has no
                // decrease-key operation, so restore the heap in linear time.
                std::make_heap(open.begin(), open.end(), openCmp);
            }
'@ "maintain AStar heap after relax"

# Connector optimization: the start-side local navmesh connector depends only on
# startPos/startNode within this getRoute() call, but the original code computes it
# only after running A*. If that connector is impossible, the A* work is wasted.
# Check/cache the start connector first for graph-reachable pairs. Keep the more
# expensive end connector after A* so routes rejected by bot-specific costs do not
# cause unnecessary end-side pathfinding. Transport behavior stays unchanged.
$loopStartMarker = "    //Cycle over the combinations of these 5 nodes.`n"
$loopEndMarker = "`n    `n    if (sPlayerbotAIConfig.hasLog(`"deadzone.csv`"))"
$loopStartIndex = $text.IndexOf($loopStartMarker)
if ($loopStartIndex -lt 0) {
    throw "Connector optimization: loop start marker not found"
}
$loopEndIndex = $text.IndexOf($loopEndMarker, $loopStartIndex)
if ($loopEndIndex -lt 0) {
    throw "Connector optimization: loop end marker not found"
}

$newLoop = @'
    std::unordered_map<TravelNode*, std::vector<WorldPosition>> goodStartPaths;

    //Cycle over the combinations of these 5 nodes.
    for (auto& endNode : endNodes)
    {
        endPath.clear();
        for (auto& startNode : startNodes)
        {
            if (std::find(badStartNodes.begin(), badStartNodes.end(), startNode) != badStartNodes.end())
                continue;

            WorldPosition startNodePosition = *startNode->getPosition();
            WorldPosition endNodePosition = *endNode->getPosition();

            float maxStartDistance = startNode->isTransport() ? 20.0f : 1.0f;

            // Preserve the original transport shortcut exactly: transport routes
            // return directly and never perform local start/end connector checks.
            if (transportEntry)
            {
                TravelNodeRoute route;
                {
                    std::unique_ptr<PerformanceMonitorOperation> pmoNodeRoute;
                    if (perfAi)
                        pmoNodeRoute = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::node-AStar", perfAi);
                    route = getRoute(startNode, endNode, unit);
                }
                return route;
            }

            // getRoute(startNode, endNode, unit) performs the same graph gate before
            // entering A*. Do it here as a cheap precheck so connector work is not
            // done for node pairs that cannot possibly have a graph route.
            if (!startNode->hasRouteTo(endNode))
                continue;

            // Check the local path from the bot to this start TravelNode before A*.
            // Cache successful connectors because the same startNode can be tested
            // against several endNodes before a route is accepted.
            bool hasStartPath = false;
            auto cachedStartPath = goodStartPaths.find(startNode);
            if (cachedStartPath != goodStartPaths.end())
            {
                newStartPath = cachedStartPath->second;
                hasStartPath = true;
            }
            else
            {
                newStartPath = startPath;
                hasStartPath = startNodePosition.cropPathTo(newStartPath, maxStartDistance);

                if (!hasStartPath)
                {
                    {
                        std::unique_ptr<PerformanceMonitorOperation> pmoStartConnector;
                        if (perfAi)
                            pmoStartConnector = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::start-connector", perfAi);
                        newStartPath = startPos.getPathTo(startNodePosition, unit);
                    }
                    hasStartPath = startNodePosition.isPathTo(newStartPath, maxStartDistance);
                }

                if (!hasStartPath)
                {
                    WorldPosition surfaceStart = startPos;
                    WorldPosition surfaceNode = startNodePosition;
                    if (surfaceStart.setAtWaterSurface() || surfaceNode.setAtWaterSurface())
                    {
                        {
                            std::unique_ptr<PerformanceMonitorOperation> pmoStartWater;
                            if (perfAi)
                                pmoStartWater = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::start-connector-water", perfAi);
                            newStartPath = surfaceStart.getPathTo(surfaceNode, unit);
                        }
                        hasStartPath = surfaceNode.isPathTo(newStartPath, maxStartDistance);
                    }
                }

                if (!hasStartPath)
                {
                    badStartNodes.push_back(startNode);
                    continue;
                }

                goodStartPaths.emplace(startNode, newStartPath);
            }

            // Only graph-reachable node pairs with a valid local start connector
            // reach the comparatively expensive TravelNode A* search.
            TravelNodeRoute route;
            {
                std::unique_ptr<PerformanceMonitorOperation> pmoNodeRoute;
                if (perfAi)
                    pmoNodeRoute = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::node-AStar", perfAi);
                route = getRoute(startNode, endNode, unit);
            }

            if (route.isEmpty())
                continue;

            // Keep the end connector after A*: it is more expensive than A* in the
            // current profile, so do not calculate it for bot-specific rejected routes.
            if (endPath.empty())
            {
                if (endPos.mapid == startPos.mapid)
                {
                    {
                        std::unique_ptr<PerformanceMonitorOperation> pmoEndConnector;
                        if (perfAi)
                            pmoEndConnector = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::end-connector", perfAi);
                        endPath = endNodePosition.getPathTo(endPos, unit);
                    }

                    bool hasEndPath = endPos.isPathTo(endPath, 1.0f);

                    if (!hasEndPath)
                    {
                        WorldPosition surfaceNode = endNodePosition;
                        WorldPosition surfaceEnd = endPos;
                        if (surfaceNode.setAtWaterSurface() || surfaceEnd.setAtWaterSurface())
                        {
                            {
                                std::unique_ptr<PerformanceMonitorOperation> pmoEndWater;
                                if (perfAi)
                                    pmoEndWater = sPerformanceMonitor.start(PERF_MON_ACTION, "TravelNodeRoutePos::end-connector-water", perfAi);
                                endPath = surfaceNode.getPathTo(surfaceEnd, unit);
                            }
                            hasEndPath = surfaceEnd.isPathTo(endPath, 1.0f);
                        }
                    }

                    if (!hasEndPath)
                    {
                        endPath.clear();
                        badEndNodes.push_back(endNode);
                        break;
                    }
                }
                else
                    endPath = {*endNode->getPosition(), endPos};
            }

            startPath = newStartPath;

            if (sPlayerbotAIConfig.hasLog("deadzone.csv"))
            {
                PathFindResult fromResult = testPathToLoop(startPos, startNodePosition, unit, uid, {startPos, startNodePosition}, "start");

                PathFindResult toResult = testPathToLoop(endNodePosition, endPos, unit, uid, {endNodePosition, endPos}, "end");

                std::vector<WorldPosition> routePoints;
                for (auto& p : route.getNodes())
                    routePoints.push_back(*p->getPosition());
                testPathToLoop(startPos, endPos, unit, uid, routePoints, "route");
            }

            return route;
        }
    }
'@

$text = $text.Substring(0, $loopStartIndex) + $newLoop + $text.Substring($loopEndIndex)

[System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "TravelNode performance optimizations applied to $Path"
