function deadFile = initializeDeadFile(RawFilename, output_dir, events)


    if isempty(events)
        return
    end

    final = [];
    for iEvent = 1:length(events)
        if contains(events(iEvent).label,'BAD')
            
            % ADD THEM ONLY IF THEY ARE EXTENDED EVENTS
            if size(events(iEvent).times,1) == 2
            
                for iiEvent = 1:size(events(iEvent).times,2)
                    final = [final num2str(events(iEvent).times(1, iiEvent)*1000) '\t' num2str(events(iEvent).times(2, iiEvent)*1000) '\n'];
                end
            end
        end
    end

    deadFile = fullfile(output_dir, ['dead_' RawFilename '.txt']);
    outFid = fopen(deadFile, 'w');
    fprintf(outFid,final);
    fclose(outFid);

end