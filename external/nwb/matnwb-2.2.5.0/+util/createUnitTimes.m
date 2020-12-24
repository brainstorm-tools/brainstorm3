function UnitTimes = createUnitTimes(cluster_ids, spike_times, spike_loc)

[sorted_cluster_ids, order] = sort(cluster_ids);
uids = unique(cluster_ids);
vdata = spike_times(order);
bounds = [0,find(diff(sorted_cluster_ids)),length(cluster_ids)];

vd = types.core.VectorData('data', vdata);
            
vd_ref = types.untyped.RegionView(spike_loc, 1:bounds(2), size(vdata));
for i = 2:length(bounds)-1
    vd_ref(end+1) = types.untyped.RegionView(spike_loc, bounds(i)+1:bounds(i+1));
end

vi = types.core.VectorIndex('data', vd_ref);
ei = types.core.ElementIdentifiers('data', int64(uids));
UnitTimes = types.core.UnitTimes('spike_times', vd, ...
    'spike_times_index', vi, 'unit_ids', ei);
