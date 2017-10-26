function obj = updateStairseries(obj, dataIndex)

%-store original stair handle-%
stair_group = obj.State.Plot(dataIndex).Handle; 

%------------------------------------------------------------------------%

%-get children-%
stair_child = get(stair_group ,'Children'); 

%------------------------------------------------------------------------%

%-update line -%
obj.State.Plot(dataIndex).Handle = stair_child(1); 
updateLineseries(obj,dataIndex); 

%------------------------------------------------------------------------%

%-revert handle-%
obj.State.Plot(dataIndex).Handle = stair_group;

end