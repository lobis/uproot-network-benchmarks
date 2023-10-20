#include "TFile.h"
#include "TRandom.h"
#include "TTree.h"
#include "TVector3.h"

void make_tree(unsigned int n_events = 10000) {
    const char* filename = "tree.root";
    const char* tree_name = "Events";

    TFile* file = new TFile(filename, "RECREATE");
    TTree tree(tree_name, tree_name);

    // Define the structure of the event
    struct Event {
        float x, y, z;
        float energy;
        int event_id;
        int event_type;
    };

    Event event;  // Create an instance of the Event structure

    tree.Branch("position.x", &event.x);
    tree.Branch("position.y", &event.y);
    tree.Branch("position.z", &event.z);
    tree.Branch("energy", &event.energy);
    tree.Branch("event_id", &event.event_id);
    tree.Branch("event_type", &event.event_type);

    // 1E8 makes a ~1.5 GB file
    for (int i = 0; i < n_events; i++) {
        event.event_id = i;
        event.event_type = gRandom->Integer(6);

        // energy random between 0 and 100 in exponential distribution
        event.energy = gRandom->Exp(100);

        // position is random uniform
        event.x = gRandom->Uniform(-100, 100);
        event.y = gRandom->Uniform(-100, 100);
        event.z = gRandom->Uniform(-100, 100);

        tree.Fill();
    }

    // Write the tree to the file
    tree.Write();
    file->Close();
}
