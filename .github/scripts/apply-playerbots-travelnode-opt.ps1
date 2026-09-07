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

[System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "TravelNode performance optimizations applied to $Path"
