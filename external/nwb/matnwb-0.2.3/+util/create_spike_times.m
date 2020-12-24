function [spike_times_vector, spike_times_index] = create_spike_times(cluster_ids, spike_times)

[sorted_cluster_ids, order] = sort(cluster_ids);
bounds = [0,find(diff(sorted_cluster_ids)),length(cluster_ids)];

spike_times_vector = types.core.VectorData('data', spike_times(order),...
    'description','spike times for all units in seconds');
            
vd_ref = types.untyped.RegionView('/units/spike_times', 1:bounds(2), size(spike_times));
for i = 2:length(bounds)-1
    vd_ref(end+1) = types.untyped.RegionView('/units/spike_times', bounds(i)+1:bounds(i+1));
end

ov = types.untyped.ObjectView('/units/spike_times');

spike_times_index = types.core.VectorIndex('data', vd_ref, 'target', ov);
