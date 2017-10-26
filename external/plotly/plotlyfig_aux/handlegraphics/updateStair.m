function obj = updateStair(obj, dataIndex)

%------------------------------------------------------------------------%

%-update line-%
updateLineseries(obj,dataIndex); 

%------------------------------------------------------------------------%

%-stair shape-%
obj.data{dataIndex}.line.shape = 'hvh'; 

%------------------------------------------------------------------------%
end