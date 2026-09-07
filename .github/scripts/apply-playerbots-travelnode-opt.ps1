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

function Replace-AllExpected {
    param(
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New,
        [Parameter(Mandatory = $true)][int]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $Old = $Old.Replace("`r`n", "`n")
    $New = $New.Replace("`r`n", "`n")
    $count = ([regex]::Matches($script:text, [regex]::Escape($Old))).Count
    if ($count -ne $Expected) {
        throw "Replacement '$Label' expected $Expected occurrences, found $count"
    }
    $script:text = $script:text.Replace($Old, $New)
}

# getRoute(WorldPosition...) only needs the five nearest candidates.  getNodes()
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

# The original A* sorts the complete open list every iteration only to remove its
# minimum element, then also performs heap operations.  A linear min_element
# preserves the selected minimum (including updated m_f values) while avoiding
# O(n log n) full sorts and the redundant heap maintenance.
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
    open.push_back(startStub);
    startStub->open = true;

    while (!open.empty())
    {
        auto currentIt = std::min_element(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });
        currentNode = *currentIt; // pop node from open for which f is minimal
        *currentIt = open.back();
        open.pop_back();
'@ "replace AStar full sort with min_element"

Replace-AllExpected @'
                open.push_back(childNode);
                std::push_heap(open.begin(), open.end(), [](TravelNodeStub* i, TravelNodeStub* j) {return i->m_f < j->m_f; });
                childNode->open = true;
'@ @'
                open.push_back(childNode);
                childNode->open = true;
'@ 1 "remove redundant AStar push_heap"

[System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "TravelNode performance optimizations applied to $Path"
