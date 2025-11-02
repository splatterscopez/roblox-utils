i'm probably never going to update this repository again, but for what it's worth, i have cleaned up GeneralModule.luau and removed it's game specific functions, so you can at least try to use it.\
\
beware! you MUST implement a handler for GeneralModule:MarkInstanceForDeletion(), i'm simply too lazy to add the loop i used in tandem with it. just replace it with debris:AddItem() if you don't care.\
\
don't let this be an indicator of my ability to program / format code.
\
\
\
~~utility modules ive made and used for my games~~

~~some of them do contain functions that relate only to my game and will be useless / wont work for yours, feel free to remove those~~\
~~^ all of the modules expect to be parented under an actor, so they intermittently make use of parallel luau, you can remove the task.desynchronize() and task.synchronize() calls if you don't plan to work with parallel luau~~


~~if you're going to make pull requests make sure you generally follow the formatting i have for the module youre editing~~
