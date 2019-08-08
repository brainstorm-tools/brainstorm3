function [dataout,condidout] = fl_condidselecthed(data,condid,hedin,hedout);
% Uses hierarchical event description to select and rename conditions

%data is nvar x ntimes x ntrials

% hedin = '*/*/*/13,14,15,16,54,55,60,64,65,69'; %keep only conditions 13,14, etc
% hedout = '*/-/-/-'; % condidout should only have the first descriptor


%     modifier = 'animate/*/*'
%     modifier = 'animate/*/1,2,3,4,5,6'
%     modifier = 'animate/*/7,8'
%     modifier = 'inanimate/*/*/54,55,60,64,65,69'


%% split hierarchical event descriptor (hed) tag
hedinsplit = strsplit(hedin,'/');
hedoutsplit = strsplit(hedout,'/');
m = length(hedinsplit);

%% split condid tags
n = length(condid);
for i = 1:n
    condidsplit{i} = strsplit(condid{i},'/');
end
keep = ones(n,1);


%% modify condid based on hedin
for i = 1:m
    
    if ~strcmp(hedinsplit{i},'*')% if not '*', then a specific tag selection is given
        
        hedinspliti = strsplit(hedinsplit{i},','); %tags to keep (separated by comma)
        for j = 1:n
            if keep(j)
                try %just in case some events's have less elements than hed modifier
                    if ~nnz(strcmp(condidsplit{j}{i},hedinspliti)) %if requested tag does not exist
                        keep(j) = 0; %discard this item
                    end
                end
            end
        end
    end
    
end
        
%% modify condid based on hedout
for i = 1:m
    
    if strcmp(hedoutsplit{i},'*') %pass input to output
        continue
    elseif strcmp(hedoutsplit{i},'-') %if remove (tag '-')
        for j = 1:n
            condidsplit{j}{i} = '-';
        end
    else %if an output name is given
        for j = 1:n
            condidsplit{j}{i} = hedoutsplit{i};
        end
    end
    
end


%% join condid tags
for i = 1:n
    condidout{i} = strjoin(condidsplit{i},'/');
end

%% keep only data with tags sharing descriptors with hed
dataout = data(:,:,keep==1);
condidout = condidout(keep==1);





return
















