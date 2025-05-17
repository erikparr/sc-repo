// VSTManager.sc
VSTManager {
    classvar <instance;
    var <vstInstances, <groups, <server, <initialized;
    
    *initClass {
        instance = nil;
    }

    *new { |server|
        if (instance.isNil) {
            instance = super.new.init(server);
        }
        ^instance;
    }

    *current { ^instance }

    init { |srvr|
        server = srvr ? Server.default;
        vstInstances = Dictionary.new;
        groups = Dictionary.new;
        this.prInitVST();
        ^this;
    }

    prInitVST {
        if (VSTPlugin.plugins.size == 0) {
            "Performing initial VST search...".postln;
            VSTPlugin.search(completion: {
                "VST search complete. Found % plugins.".format(VSTPlugin.plugins.size).postln;
            });
        };
        initialized = true;
    }

    // VST Instance Management
    
    // Get all VST instances as a dictionary of name -> controller
    getInstances {
        var instances = Dictionary.new;
        vstInstances.keysValuesDo { |name, instance|
            instances[name] = instance.controller;
        };
        ^instances;
    }
    
    addVST { |name, synth, vstPath, editor=true, groupName=nil, action|
        var vstCtrl, instance;
        
        if (vstInstances[name].notNil) {
            ("VST instance '" ++ name ++ "' already exists").warn;
            ^vstInstances[name];
        };
        
        // Add VST instance directly - the search will complete asynchronously
        this.prAddVSTInstance(name, synth, vstPath, editor, groupName, action);
    }
    
    prAddVSTInstance { |name, synth, vstPath, editor, groupName, action|
        var vstCtrl = VSTPluginController(synth, name.asSymbol);
        var instance = (
            name: name,
            controller: vstCtrl,
            synth: synth,
            path: vstPath,
            group: groupName,
            params: Dictionary.new
        );
        
        vstInstances[name] = instance;
        
        // Add to group if specified
        if (groupName.notNil) {
            this.addToGroup(groupName, name);
        };
        
        // Open VST
        vstCtrl.open(vstPath, editor: editor, action: {
            this.prUpdateParameters(name);
            ("VST loaded: " ++ name).postln;
        });
        
        ^instance;
    }

    removeVST { |name|
        var instance = vstInstances[name];
        if (instance.notNil) {
            // Remove from group if in one
            if (instance.group.notNil) {
                this.removeFromGroup(instance.group, name);
            };
            
            // Close VST and clean up
            instance.controller.close;
            vstInstances.removeAt(name);
            ^true;
        };
        ^false;
    }

    // Group Management
    createGroup { |name, vstNames|
        groups[name] = vstNames.select { |n| vstInstances[n].notNil };
        ^groups[name];
    }

    addToGroup { |groupName, vstName|
        var instance = vstInstances[vstName];
        if (instance.notNil) {
            // Remove from old group if any
            if (instance.group.notNil) {
                this.removeFromGroup(instance.group, vstName);
            };
            
            // Add to new group
            groups[groupName] = groups[groupName].add(vstName);
            instance.group = groupName;
            ^true;
        };
        ^false;
    }

    removeFromGroup { |groupName, vstName|
        var group = groups[groupName];
        if (group.notNil) {
            var instance = vstInstances[vstName];
            if (instance.notNil) {
                groups[groupName].remove(vstName);
                instance.group = nil;
                ^true;
            };
        };
        ^false;
    }

    // Parameter Control
    setParameter { |target, param, value|
        var instances = this.resolveTarget(target);
        instances.do { |name|
            var instance = vstInstances[name];
            if (instance.notNil) {
                instance.controller.set(param, value);
                instance.params[param] = value;
            };
        };
    }

    getParameter { |target, param, action|
        var instance = vstInstances[target];
        if (instance.notNil) {
            instance.controller.get(param, { |val|
                instance.params[param] = val;
                action.value(val);
            });
        };
    }

    // Private Methods
    prUpdateParameters { |name|
        var instance = vstInstances[name];
        if (instance.notNil) {
            // Get all parameters at once using getn
            // params is an array of values, where the index in the array is the parameter index
            instance.controller.getn(0, -1, { |values|
                values.do { |value, index|
                    instance.params[index] = value;
                };
                ("Updated " + values.size + " parameters for " + name).postln;
            });
        };  
    }

    resolveTarget { |target|
        ^if (groups[target].notNil) {
            groups[target]
        } {
            if (vstInstances[target].notNil) {
                [target]
            } {
                []
            };
        };
    }

    // Utility
    getState {
        var state = (
            instances: Dictionary.new,
            groups: groups
        );
        
        vstInstances.keysValuesDo { |name, inst|
            state.instances[name] = (
                name: name,
                path: inst.path,
                group: inst.group,
                params: inst.params
            );
        };
        
        ^state;
    }
}