function varargout = process_fast_graph( varargin )

% PROCESS_FAST_BASIC: Fast graphs with minimal functionality

% Authors: Ken Taylor, 8/12/2024

% initial version from old code 8/12/2024

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'FAST Graph';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Plots';
    sProcess.Index       = 1100;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(~, sInput)
    % Initialize returned list of files
    OutputFiles = {};
    
    [sSubject, ~] = bst_get('Subject');
    cortexLink = sSubject.Surface(sSubject.iCortex);
    if ~isempty(cortexLink)
        cortex = load(file_fullpath(cortexLink.FileName));
    end
    
    fig = figure;
    max_axis = [];
    clear ax
    set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.
    
    % load in the SEEG data block
    [Dcell,Fcell,ch] = getSEEG(sInput);
    
    % set the number of subplots depending on graph type
    numSubplots = length(sInput);
    
    for subplotNum = 1:numSubplots
    
        [Inds,noLocations] = sortSEEG(sInput);
        % get the data used in each subplot
        [subplotData] = getSubplotData(subplotNum,Fcell,Inds);
    
        % apply the chosen sort method
        [sorted] = applySorting(subplotData,ch,Inds);
    
        % generate each subplot
        % this m n thing is for setting the number of rows and cols when
        % plotting multiple sets of data at once
        m = max([floor(numSubplots/6) 1]);
        n = ceil(numSubplots/max([floor(sqrt(numSubplots/1.5)) 1]));
        subtightplot(m,n,subplotNum,[0.075 0.0175],0.03,0.015)
        % [h1, h2] = createSubplot(subplotNum,sInput,Dcell{subplotNum},subplotData,Fcell,Inds,noLocations,cortex);
        [h1, h2] = createSubplot(subplotNum,sInput,Dcell{subplotNum},sorted.Vals,Fcell,sorted.Inds,noLocations,cortex);
    
        % manipulate plots to make them more readable
        axis tight
        axis_temp = axis;
        ax(subplotNum) = gca;
        if subplotNum == 1
            max_axis = axis_temp;
        else
            max_axis(3) = min(max_axis(3),axis_temp(3));
            max_axis(4) = max(max_axis(4),axis_temp(4));
        end
        if exist('h1','var')
            set(h1,'edgealpha',0.01);
        end
        if exist('h2','var')
            set(h2,'edgealpha',0.01);
        end
    end
    
    % more plot manipulations
    for subplotNum = 1:numSubplots-1
        ax(subplotNum).YLim = max_axis(3:4);
    end
    linkaxes(ax)
    set(gcf,'units','normalized','outerposition',[0 0 1 1])
    shg
    zoom yon
end

%%
function [Dcell,Fcell,ch] = getSEEG(sInput)
    % load in the SEEG data block
    Fcell = cell(length(sInput),1);
    
    % I think channel file has to be the same for each input so only need to
    % get ch once, doing it each time for now anyway just in case
    for k = 1:length(sInput)
        % get the channel information & SEEG data
        ch = load(file_fullpath(sInput(k).ChannelFile));
        data = load(file_fullpath(sInput(k).FileName));
        data.F(data.ChannelFlag<0,:) = NaN;
        SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
        Fcell(k) = {data.F(SEEGcontacts,:)};
        Dcell(k) = {data};
    end
end

%%
function [Inds,noLocations] = sortSEEG(sInput)
    % get the channel information (assumed equal for all input files)
    ch = load(file_fullpath(sInput(1).ChannelFile));
    
    % sort the contact locations
    SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
    Inds.Left = zeros(1,length(SEEGcontacts));
    
    % if no locations available distinguish left from right using the '
    % note that this doesn't account for "push through" electrodes that cover
    % both hemispheres, but a good basic start
    noLocations = 0;
    
    temp_ind = 1;
    for i = SEEGcontacts
        if length(ch.Channel(i).Group)>1
            Inds.Left(temp_ind) = strcmp(ch.Channel(i).Group(2),'''');
        end
        temp_ind = temp_ind + 1;
    end
    Inds.Left = logical(Inds.Left);
    Inds.Right = ~Inds.Left;
    
    if noLocations
        temp_ind = 1;
        for i = SEEGcontacts
            if length(ch.Channel(i).Group)>1
                Inds.Left(temp_ind) = strcmp(ch.Channel(i).Group(2),'''');
            end
            temp_ind = temp_ind + 1;
        end
        Inds.Left = logical(Inds.Left);
        Inds.Right = ~Inds.Left;
    else
        contact_locs = zeros(3,length(SEEGcontacts));
        for i = 1:length(SEEGcontacts)
            contact_locs(:,i) = ch.Channel(SEEGcontacts(i)).Loc;
        end
        % [Inds] = sortLAPPAR(contact_locs');
        % instead of this sorting, we want to separate left and right, and then
        % group by label.
        % [Inds] = sortLabel(ch);
    end
end

%%
function [subplotData] = getSubplotData(subplotNum,Fcell,Inds)
    % get the data that will be used in each subplot
    subplotData.leftData = [];
    subplotData.rightData = [];
    subplotData.allData = [];
    
    Fout = Fcell{subplotNum};
    if any(Inds.Left)
        subplotData.leftData = Fout(Inds.Left,:);
    end
    if any(Inds.Right)
        subplotData.rightData = Fout(Inds.Right,:);
    end
end

%%
function [sorted] = applySorting(subplotData,ch,Inds)
    SEEGinds = find(strcmp('SEEG',{ch.Channel.Type}));
    chSEEG = ch.Channel(SEEGinds);
    chSEEGleft = chSEEG(Inds.Left);
    chSEEGright = chSEEG(Inds.Right);
    [sorted.Labels.Left,sorted.Inds.Left] = sort({chSEEGleft.Comment});
    [sorted.Labels.Right,sorted.Inds.Right] = sort({chSEEGright.Comment});
    sorted.Vals.Left = subplotData.leftData(sorted.Inds.Left);
    sorted.Vals.Right = subplotData.rightData(sorted.Inds.Right);
    
    % if isempty(userInput.SortWindow)
    %     SortWindowIndx = 1:size(data.F,2);
    % else
    %     SortWindowIndx = userInput.SortWindow(1):userInput.SortWindow(2);
    % end
    % sorted.Inds.Left = [];
    % sorted.Inds.Right = [];
    % sorted.Inds.All = [];
    % % apply the chosen sort method
    % switch userInput.sortMethod
    % 
    %     case 1 % 'std'
    %         % sort inside out using stand deviation
    %         switch userInput.Separate
    %             case 1
    %                 if ~isempty(subplotData.leftData)
    %                     leftDataStd = std(subplotData.leftData(:,SortWindowIndx),0,2);
    %                     leftDataStd(isnan(leftDataStd)) = -Inf;
    %                     [sorted.Vals.Left,sorted.Inds.Left] = sort(leftDataStd,'ascend');
    %                 end
    %                 if ~isempty(subplotData.rightData)
    %                     rightDataStd = std(subplotData.rightData(:,SortWindowIndx),0,2);
    %                     rightDataStd(isnan(rightDataStd)) = -Inf;
    %                     [sorted.Vals.Right,sorted.Inds.Right] = sort(rightDataStd,'ascend');
    %                 end
    %             case 2
    %                 allDataStd = std(subplotData.allData(:,SortWindowIndx),0,2);
    %                 [sorted.Vals.All,sorted.Inds.All] = sort(allDataStd,'ascend');
    %         end
    %     case 2 %'abs max'
    %         % sort inside out using max absolute value
    %         switch userInput.Separate
    %             case 1
    %                 if ~isempty(subplotData.leftData)
    %                     leftDataMax = max(abs(subplotData.leftData(:,SortWindowIndx)),[],2);
    %                     leftDataMax(isnan(leftDataMax)) = -Inf;
    %                     [sorted.Vals.Left,sorted.Inds.Left] = sort(leftDataMax,1,'ascend');
    %                 end
    %                 if ~isempty(subplotData.rightData)
    %                     rightDataMax = max(abs(subplotData.rightData(:,SortWindowIndx)),[],2);
    %                     rightDataMax(isnan(rightDataMax)) = -Inf;
    %                     [sorted.Vals.Right,sorted.Inds.Right] = sort(rightDataMax,1,'ascend');
    %                 end
    %             case 2
    %                 allDataMax = max(abs(subplotData.allData(:,SortWindowIndx)),[],2);
    %                 [sorted.Vals.All,sorted.Inds.All] = sort(allDataMax,2,'ascend');
    %         end
    %     otherwise
    %         error('wrong switch')
    % end
end

%%
function [sortedLocs] = sortLAPPAR(locs)
    % returns the index of locations sorted by
    % (L)eft side (A)nterior to (P)osterior (LAP),
    % then (P)osterior to (A)nterior on the (R)ight (PAR)
    % given input [x-pos; y-pos; z-pos] of electrode locations
    
    % separate out the left and right sides
    lhemi = locs(locs(:,2) >= 0,:);
    rhemi = locs(locs(:,2) <  0,:);
    
    % sort the left side descending, and right side ascending
    % LAPPAR_sorted = [fliplr(sortrows(lhemi,1)') sortrows(rhemi,1)'];
    LAPPAR_sorted = [fliplr(sortrows(lhemi,1)') fliplr(sortrows(rhemi,1)')];
    % relate sorted electrodes to input to find indices
    % all = zeros(1,size(LAPPAR_sorted,2));
    % for i = 1:size(LAPPAR_sorted,2)
    %     all(i) = find(locs(:,1)==LAPPAR_sorted(1,i));
    % end
    % instead to account for duplicate locations
    sortedLocs.All = [];
    for i = 1:size(unique(LAPPAR_sorted','rows'),1)
        x = find(locs(:,1)'==LAPPAR_sorted(1,i)');
        y = find(locs(:,2)'==LAPPAR_sorted(2,i)');
        z = find(locs(:,3)'==LAPPAR_sorted(3,i)');
        sortedLocs.All = [sortedLocs.All intersect(intersect(x,y),z)];
    end
    leftrows = fliplr(sortrows(lhemi,1)');
    rightrows = sortrows(rhemi,1)';
    % left = zeros(1,size(leftrows,2));
    % right = zeros(1,size(rightrows,2));
    % for i = 1:size(leftrows,2)
    %     left(i) = find(locs(:,1)==leftrows(1,i));
    % end
    % for i = 1:size(rightrows,2)
    %     right(i) = find(locs(:,1)==rightrows(1,i));
    % end
    sortedLocs.Left = [];
    sortedLocs.Right = [];
    for i = 1:size(unique(leftrows','rows'),1)
        x = find(locs(:,1)'==leftrows(1,i)');
        y = find(locs(:,2)'==leftrows(2,i)');
        z = find(locs(:,3)'==leftrows(3,i)');
        sortedLocs.Left = [sortedLocs.Left intersect(intersect(x,y),z)];
    end
    for i = 1:size(unique(rightrows','rows'),1)
        x = find(locs(:,1)'==rightrows(1,i)');
        y = find(locs(:,2)'==rightrows(2,i)');
        z = find(locs(:,3)'==rightrows(3,i)');
        sortedLocs.Right = [sortedLocs.Right intersect(intersect(x,y),z)];
    end
end

%%
function region = applyRegionColor(loc_region,cortex,aaa)
    % returns the color that a region should be based on the location
    
    % assume we are using USCLobes atlas for now
    % in future can use the cortex to determine what Atlas is in use
    m = 1;
    search_on = 1;
    % look for a match for the channel label in the atlas
    while (m <= length(aaa.labelset.label)) && search_on
        if strcmp(aaa.labelset.label{m}.Attributes.fullname, loc_region)
            search_on = 0;
        else
            m = m+1;
        end
    end
    % if you find a match get the corresponding color
    if m < length(aaa.labelset.label)
        region.Name = aaa.labelset.label{m}.Attributes.fullname;
        region.Color = aaa.labelset.label{m}.Attributes.color;
        region.Color = hex2rgb(region.Color(3:end));
    else
        region.Color = [1, 1, 1]*0.5;
        region.Name = '?';
    end

end

%%
function h=subtightplot(m,n,p,gap,marg_h,marg_w,varargin)
    %function h=subtightplot(m,n,p,gap,marg_h,marg_w,varargin)
    %
    % Functional purpose: A wrapper function for Matlab function subplot. Adds the ability to define the gap between
    % neighbouring subplots. Unfotrtunately Matlab subplot function lacks this functionality, and the gap between
    % subplots can reach 40% of figure area, which is pretty lavish.
    %
    % Input arguments (defaults exist):
    %   gap- two elements vector [vertical,horizontal] defining the gap between neighbouring axes. Default value
    %            is 0.01. Note this vale will cause titles legends and labels to collide with the subplots, while presenting
    %            relatively large axis.
    %   marg_h  margins in height in normalized units (0...1)
    %            or [lower uppper] for different lower and upper margins
    %   marg_w  margins in width in normalized units (0...1)
    %            or [left right] for different left and right margins
    %
    % Output arguments: same as subplot- none, or axes handle according to function call.
    %
    % Issues & Comments: Note that if additional elements are used in order to be passed to subplot, gap parameter must
    %       be defined. For default gap value use empty element- [].
    %
    % Usage example: h=subtightplot((2,3,1:2,[0.5,0.2])

    if (nargin<4) || isempty(gap),    gap=0.01;  end
    if (nargin<5) || isempty(marg_h),  marg_h=0.05;  end
    if (nargin<5) || isempty(marg_w),  marg_w=marg_h;  end
    if isscalar(gap),   gap(2)=gap;  end
    if isscalar(marg_h),  marg_h(2)=marg_h;  end
    if isscalar(marg_w),  marg_w(2)=marg_w;  end
    gap_vert   = gap(1);
    gap_horz   = gap(2);
    marg_lower = marg_h(1);
    marg_upper = marg_h(2);
    marg_left  = marg_w(1);
    marg_right = marg_w(2);
    
    %note n and m are switched as Matlab indexing is column-wise, while subplot indexing is row-wise :(
    [subplot_col,subplot_row]=ind2sub([n,m],p);
    
    % note subplot suppors vector p inputs- so a merged subplot of higher dimentions will be created
    subplot_cols=1+max(subplot_col)-min(subplot_col); % number of column elements in merged subplot
    subplot_rows=1+max(subplot_row)-min(subplot_row); % number of row elements in merged subplot
    
    % single subplot dimensions:
    %height=(1-(m+1)*gap_vert)/m;
    %axh = (1-sum(marg_h)-(Nh-1)*gap(1))/Nh;
    height=(1-(marg_lower+marg_upper)-(m-1)*gap_vert)/m;
    %width =(1-(n+1)*gap_horz)/n;
    %axw = (1-sum(marg_w)-(Nw-1)*gap(2))/Nw;
    width =(1-(marg_left+marg_right)-(n-1)*gap_horz)/n;
    
    % merged subplot dimensions:
    merged_height=subplot_rows*( height+gap_vert )- gap_vert;
    merged_width= subplot_cols*( width +gap_horz )- gap_horz;
    
    % merged subplot position:
    merged_bottom=(m-max(subplot_row))*(height+gap_vert) +marg_lower;
    merged_left=(min(subplot_col)-1)*(width+gap_horz) +marg_left;
    pos_vec=[merged_left merged_bottom merged_width merged_height];
    
    % h_subplot=subplot(m,n,p,varargin{:},'Position',pos_vec);
    % Above line doesn't work as subplot tends to ignore 'position' when same mnp is utilized
    h=subplot('Position',pos_vec,varargin{:});
    
    if (nargout < 1),  clear h;  end

end

%%
function [h1, h2] = createSubplot(subplotNum,sInput,data,subplotData,Fcell,Inds,noLocations,cortex)
    h1 = [];
    h2 = [];
    
    % set the indexing for the window of data to plot over
    PlotWindowIndx = 1:size(Fcell{subplotNum},2);
    
    % get the channel information (assumed equal for all input files)
    chLink = file_fullpath(sInput(1).ChannelFile);
    ch = load(chLink);
    SEEGcontacts = find(strcmp('SEEG',{ch.Channel.Type}));
    aaa = xml2struct('C:\Users\chinm\OneDrive\Desktop\brainsuite_labeldescription.xml');  
    if ~isempty(subplotData.Left)
    
        Fout = Fcell{subplotNum};
        Xl = abs(Fout(Inds.Left,:));
    
        % %% region selection update
        % plot_locs = SEEGcontacts(Inds.Left);
        % num_plot_locs = length(plot_locs);
        % 
        % leftRegions = cell(1,num_plot_locs);
        % leftSelections = cell(1,num_plot_locs);
        % jetset = jet(num_plot_locs);
        % for i = 1:num_plot_locs
        %     if noLocations
        %         h1(i).FaceColor = jetset(i,:);
        %     else
        %         region = applyRegionColor(ch.Channel(plot_locs(i)).Comment,cortex);
        %         leftRegions{i} = region.Name;
        %         leftSelections{i} = ch.Channel(plot_locs(i)).Comment;
        %     end
        % end
    
        clear h1
        h1 = area(data.Time(PlotWindowIndx)*1000,Xl(:,PlotWindowIndx)');
    
        % for loop to do subplots for left side of the brain
        plot_locs = SEEGcontacts(Inds.Left);
        num_plot_locs = length(plot_locs);
    
        jetset = jet(num_plot_locs);
        leftRegions = cell(1,num_plot_locs);
        disp(' ')
        disp('left side contacts')
        disp(' ')
        for i = 1:num_plot_locs
            if noLocations
                h1(i).FaceColor = jetset(i,:);
            else
                region = applyRegionColor(ch.Channel(plot_locs(i)).Comment,cortex,aaa);
                leftRegions{i} = region.Name;
                h1(i).FaceColor = region.Color;
            end
        end
        %%
        hold on
    end
    % check for contacts on the right side, plot if they exist
    
    if ~isempty(subplotData.Right)
    
        Fout = Fcell{subplotNum};
        %                     Xr = F(Inds.Right(sortedInds.Right),:,subplotNum);
        Xr = Fout(Inds.Right,:);
        Xr = abs(Xr);
    
        % %% region selection update
        % plot_locs = SEEGcontacts(Inds.Right);
        % num_plot_locs = length(plot_locs);
        % rightRegions = cell(1,num_plot_locs);
        % rightSelections = cell(1,num_plot_locs);
        % disp(' ')
        % disp('right side contacts')
        % disp(' ')
        % for i = 1:num_plot_locs
        %     if noLocations
        %         h2(i).FaceColor = jetset(i,:);
        %     else
        %         region = applyRegionColor(userInput,ch.Channel(plot_locs(i)).Comment,cortex);
        %         rightRegions{i} = region.Name;
        %         rightSelections{i} = ch.Channel(plot_locs(i)).Comment;
        %     end
        % end
    
        clear h2
        h2 = area(data.Time(PlotWindowIndx)*1000,-Xr(:,PlotWindowIndx)');
    
        plot_locs = SEEGcontacts(Inds.Right);
        num_plot_locs = length(plot_locs);
    
        jetset = jet(num_plot_locs);
        rightRegions = cell(1,num_plot_locs);
        disp(' ')
        disp('right side contacts')
        disp(' ')
        for i = 1:num_plot_locs
            if noLocations
                h2(i).FaceColor = jetset(i,:);
            else
                region = applyRegionColor(ch.Channel(plot_locs(i)).Comment,cortex,aaa);
                rightRegions{i} = region.Name;
                h2(i).FaceColor = region.Color;
            end
        end
        %%
        hold off
    end
end

%%
function [ s ] = xml2struct( file )
    %Convert xml file into a MATLAB structure
    % [ s ] = xml2struct( file )
    %
    % A file containing:
    % <XMLname attrib1="Some value">
    %   <Element>Some text</Element>
    %   <DifferentElement attrib2="2">Some more text</Element>
    %   <DifferentElement attrib3="2" attrib4="1">Even more text</DifferentElement>
    % </XMLname>
    %
    % Will produce:
    % s.XMLname.Attributes.attrib1 = "Some value";
    % s.XMLname.Element.Text = "Some text";
    % s.XMLname.DifferentElement{1}.Attributes.attrib2 = "2";
    % s.XMLname.DifferentElement{1}.Text = "Some more text";
    % s.XMLname.DifferentElement{2}.Attributes.attrib3 = "2";
    % s.XMLname.DifferentElement{2}.Attributes.attrib4 = "1";
    % s.XMLname.DifferentElement{2}.Text = "Even more text";
    %
    % Please note that the following characters are substituted
    % '-' by '_dash_', ':' by '_colon_' and '.' by '_dot_'
    %
    % Written by W. Falkena, ASTI, TUDelft, 21-08-2010
    % Attribute parsing speed increased by 40% by A. Wanner, 14-6-2011
    % Added CDATA support by I. Smirnov, 20-3-2012
    %
    % Modified by X. Mo, University of Wisconsin, 12-5-2012

    if (nargin < 1)
        clc;
        help xml2struct
        return
    end
    
    if isa(file, 'org.apache.xerces.dom.DeferredDocumentImpl') || isa(file, 'org.apache.xerces.dom.DeferredElementImpl')
        % input is a java xml object
        xDoc = file;
    else
        %check for existance
        if (exist(file,'file') == 0)
            %Perhaps the xml extension was omitted from the file name. Add the
            %extension and try again.
            if (isempty(strfind(file,'.xml')))
                file = [file '.xml'];
            end
            
            if (exist(file,'file') == 0)
                error(['The file ' file ' could not be found']);
            end
        end
        %read the xml file
        xDoc = xmlread(file);
    end
    
    %parse xDoc into a MATLAB structure
    s = parseChildNodes(xDoc);
end

%% ----- Subfunction parseChildNodes -----
function [children,ptext,textflag] = parseChildNodes(theNode)
    % Recurse over node children.
    children = struct;
    ptext = struct; textflag = 'Text';
    if hasChildNodes(theNode)
        childNodes = getChildNodes(theNode);
        numChildNodes = getLength(childNodes);
        for count = 1:numChildNodes
            theChild = item(childNodes,count-1);
            [text,name,attr,childs,textflag] = getNodeData(theChild);
            
            if (~strcmp(name,'#text') && ~strcmp(name,'#comment') && ~strcmp(name,'#cdata_dash_section'))
                %XML allows the same elements to be defined multiple times,
                %put each in a different cell
                if (isfield(children,name))
                    if (~iscell(children.(name)))
                        %put existsing element into cell format
                        children.(name) = {children.(name)};
                    end
                    index = length(children.(name))+1;
                    %add new element
                    children.(name){index} = childs;
                    if(~isempty(fieldnames(text)))
                        children.(name){index} = text; 
                    end
                    if(~isempty(attr)) 
                        children.(name){index}.('Attributes') = attr; 
                    end
                else
                    %add previously unknown (new) element to the structure
                    children.(name) = childs;
                    if(~isempty(text) && ~isempty(fieldnames(text)))
                        children.(name) = text; 
                    end
                    if(~isempty(attr)) 
                        children.(name).('Attributes') = attr; 
                    end
                end
            else
                ptextflag = 'Text';
                if (strcmp(name, '#cdata_dash_section'))
                    ptextflag = 'CDATA';
                elseif (strcmp(name, '#comment'))
                    ptextflag = 'Comment';
                end
                
                %this is the text in an element (i.e., the parentNode) 
                if (~isempty(regexprep(text.(textflag),'[\s]*','')))
                    if (~isfield(ptext,ptextflag) || isempty(ptext.(ptextflag)))
                        ptext.(ptextflag) = text.(textflag);
                    else
                        %what to do when element data is as follows:
                        %<element>Text <!--Comment--> More text</element>
                        
                        %put the text in different cells:
                        % if (~iscell(ptext)) ptext = {ptext}; end
                        % ptext{length(ptext)+1} = text;
                        
                        %just append the text
                        ptext.(ptextflag) = [ptext.(ptextflag) text.(textflag)];
                    end
                end
            end
            
        end
    end
end

%% ----- Subfunction getNodeData -----
function [text,name,attr,childs,textflag] = getNodeData(theNode)
    % Create structure of node info.
    %make sure name is allowed as structure name
    name = toCharArray(getNodeName(theNode))';
    name = strrep(name, '-', '_dash_');
    name = strrep(name, ':', '_colon_');
    name = strrep(name, '.', '_dot_');

    attr = parseAttributes(theNode);
    if (isempty(fieldnames(attr))) 
        attr = []; 
    end
    
    %parse child nodes
    [childs,text,textflag] = parseChildNodes(theNode);
    
    if (isempty(fieldnames(childs)) && isempty(fieldnames(text)))
        %get the data of any childless nodes
        % faster than if any(strcmp(methods(theNode), 'getData'))
        % no need to try-catch (?)
        % faster than text = char(getData(theNode));
        text.(textflag) = toCharArray(getTextContent(theNode))';
    end
    
end

%% ----- Subfunction parseAttributes -----
function attributes = parseAttributes(theNode)
    % Create attributes structure.
    attributes = struct;
    if hasAttributes(theNode)
       theAttributes = getAttributes(theNode);
       numAttributes = getLength(theAttributes);

       for count = 1:numAttributes
            %attrib = item(theAttributes,count-1);
            %attr_name = regexprep(char(getName(attrib)),'[-:.]','_');
            %attributes.(attr_name) = char(getValue(attrib));

            %Suggestion of Adrian Wanner
            str = toCharArray(toString(item(theAttributes,count-1)))';
            k = strfind(str,'='); 
            attr_name = str(1:(k(1)-1));
            attr_name = strrep(attr_name, '-', '_dash_');
            attr_name = strrep(attr_name, ':', '_colon_');
            attr_name = strrep(attr_name, '.', '_dot_');
            attributes.(attr_name) = str((k(1)+2):(end-1));
       end
    end
end