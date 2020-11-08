classdef node < handle
    % NODE Helper class for circularGraph. Not intended for direct user manipulation.
    %%
    % Copyright 2016 The MathWorks, Inc.
    properties (Access = public)
        Label = '';             % String
        Links = line(0,0); % Array of lines
        Position;               % [x,y] coordinates
        Color = [0.7 0.7 0.7];  % [r g b] default grey node
        LabelColor = [1 1 1]    % [r g b] default white
        Visible = true;         % Logical true or false
        isAgregatingNode = false; % if this node is a grouped node/scout /lobe
        LabelVisible = true;    % logical true or false if label is visible or not
    end
    
    properties (Access = public, Dependent = true)
        Extent; % Width of text label
    end
    
    properties (Access = private)
        TextLabel;    % Text graphics object
        NodeMarker;   % Line that makes the node visible
        Marker = 'o'; % Marker symbol when the node is 'on'
    end
    
    properties (Access = private, Constant)
        labelOffsetFactor = 1.05;
    end
    
    methods
        function this = node(x,y)
            % Constructor
            this.Position = [x,y];
            this.Links = line(0,0);
            makeLine(this);
        end
        
        function makeLine(this)
            % Make the node's line graphic object
            this.NodeMarker = line(...
                this.Position(1),...
                this.Position(2),...
                -2,... #z coordinate 
                'Color',this.Color,...
                'Marker',this.Marker,...
                'MarkerFaceColor', this.Color,...
                'MarkerSize', 5,... #default (6) is too big
                'LineStyle','none',...
                'PickableParts','all',...
                'ButtonDownFcn',@node.ButtonDownFcn,...
                'UserData',this);
        end
        
        function set.Visible(this,value)
            this.Visible = value;
            updateVisible(this);
        end
        
        function set.LabelVisible(this,value)
            this.LabelVisible = value;
            updateLabelVisible(this);
        end
        
        function set.Color(this,value)
            this.Color = value;
            updateColor(this);
        end
        
        function set.Label(this,value)
            this.Label = value;
            updateTextLabel(this);
        end
        
        function set.isAgregatingNode(this,value)
            this.isAgregatingNode = value;
            % updateAgregatingNode(this); % added Oct 25, bug?
            updateTextLabel(this);
        end
        
        function set.LabelColor(this,value)
            this.LabelColor = value;
            updateTextLabelColor(this);
        end
        
        function value = get.Extent(this)
            value = this.TextLabel.Extent(3);
        end
        
        % TODO to identify nodes linked to a selected lobe
        %function setSelectedNodes()
            
        %end
        
        function updateVisible(this)
            if this.Visible
                this.NodeMarker.Marker = 'o';
                this.NodeMarker.MarkerSize = 5;
                this.NodeMarker.MarkerFaceColor = this.Color;
                set(this.Links,'Color',this.Color);
                
                for i = 1:length(this.Links)
                    this.Links(i).ZData = ones(size(this.Links(i).XData));
                end
            else
                this.NodeMarker.Marker = 'diamond'; % changed on Oct 25
                this.NodeMarker.MarkerSize = 8; % changed on Oct 25
                this.NodeMarker.MarkerFaceColor = 'red'; % changed on Oct 25
                set(this.Links,'Color',[1 1 1]);
                
                for i = 1:length(this.Links)
                    this.Links(i).ZData = zeros(size(this.Links(i).XData));
                end
            end
        end
        
        function updateLabelVisible(this)
            if (this.LabelVisible)
                this.TextLabel.Visible = 'on';
            else 
                this.TextLabel.Visible = 'off';
            end
        end
        
        function updateColor(this)
            this.NodeMarker.Color = this.Color;
            this.NodeMarker.MarkerFaceColor = this.Color; % set marker fill color
            set(this.Links,'Color',this.Color); % set links color %todo: this will be replaced by color map for connectivity intensity
        end
        
        function updateTextLabelColor(this)
            set(this.TextLabel,'Color',this.LabelColor);
        end
        
        function updateTextLabel(this)
            delete(this.TextLabel);
            
            x = this.Position(1);
            y = this.Position(2);
            t = atan2(y,x);
            
            this.TextLabel = text(0,0,this.Label, 'Interpreter', 'none'); % display with '_'
            this.TextLabel.Position = node.labelOffsetFactor*this.Position;
            this.TextLabel.FontSize = this.TextLabel.FontSize-3; %default size too big
            if (this.LabelVisible)
                this.TextLabel.Visible = 'on';
            else 
                this.TextLabel.Visible = 'off';
            end
            
            %rotate and align labels
            if (~this.isAgregatingNode)
                if abs(t) > pi/2
                    this.TextLabel.Rotation = 180*(t/pi + 1);
                else
                    this.TextLabel.Rotation = t*180/pi;
                end
            end
            
            if abs(t) > pi/2
                this.TextLabel.HorizontalAlignment = 'right';
            end
        end
        
        function delete(this)
            % Destructor
            delete(this.Links(:))
            delete(this.TextLabel);
            delete(this.NodeMarker);
            delete(this);
        end
        
    end
    
    methods (Static = true)
        
        %node was selected/unselected by mouse click
        function ButtonDownFcn(this,~)
            n = this.UserData;
            disp(n.Label + " clicked");
          
            if n.Visible % can just change to n.Visible = ~n.Visible? 
                n.Visible = false;
            else
                n.Visible = true;
            end
            
            % TODO: Implement function similar to JavaClickCallback +
            % SetSelectedNodes to form aggregates
            % SetSelectedNodes(hFig, iNodes, isSelected, isRedraw)
            
        end
    end
end