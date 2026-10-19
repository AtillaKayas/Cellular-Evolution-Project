# Cellular Evolution Project
 Simple cells with simple genomes and peptides that can evolve.

![Simulation screenshot](screenshot.png)

## Status

**Work in progress.** The genome, peptide, chemistry, membrane transport and glycolysis systems are implemented. The cells seem to be able to grow exponentially but with great cost to performance, and also there isn't a stable state for intracellular concentrations as of yet.

## How to run

1. Install Godot 4.7.2.stable
2. Import the project from the Godot's menu and hit 'Import & Run'
3. Press Play.
4. You'll see the starter cell represented by a circle in the middle. Below it are the contents of its Cytosol. Clicking a substance will open a menu giving various debug information about how it currently behaves. A way to view the Genome and Proteome are yet to be implemented, you'll have to check the code for them.
## Design overview

### Cells
Cells are represented by circles on the screen. A starter cell has a volume of 8 pL while the medium it lives in is around 1L.

### Substances

- **Substances** are denoted by single characters, but they also have nicknames for clarity.
- They have mass and charge, which are important in some calculations.
- They have a peptide pattern which allows peptides to specifically bind to them, more about this later.

### Genome
- There are 4 Nucleotides: a, b, c, d.
- 2 Nucleotides form 1 Codon, giving us the total of 16 amino acids all denoted by capital letters A through P.
- Nucleotides come together to form **Nucleins**.
- Nucleins are named after their sequence, though they can also be nicknamed.
- There are Protomoter and Terminator sequences on Nucleins, which encode **Peptides**.
- The next codon after the promoter is the binding site that is activated by that specific RNA Polymerase.
- There can be up to 16 specific promoter binding sites.
- A genome contains multiple nucleins but the starter cell only has 1.

### Peptides and Proteome
- Amino Acids come together to form Peptides.
- Peptides are not a subclass of Substance and their name is the sequence of amino acids they contain.
- For instance, the peptide "AICLONAA" is the starter RNA Polymerase that reads the genome and synthesises all of the starter peptides.
- Peptides have certain sequences on them that allow for specific tasks. For example, "ICLON" stands for RNA Polymerase the next two amino acids that come after that, A and A, denote the rate of transcription and which DNA binding site is used. Together, Peptides create Proteome.

### Fluids, Chemistry, and Operations
- Substances are stored in **Fluids**.
- A Chemistry stores a certain composition of Fluid and Proteome and simplifies the effects of peptides on the Fluid.
- If the Peptide or Substance composition changes, then the cell switches to a different Chemistry, allowing for easier processing.
- Chemistry does all of its operations through a class called Operations for the sake of simplicity.
- Chemistry class only deals with what peptides it can make out of a given Genome and Fluid and wheter it is applicable to current conditions
- Operation carries out what Peptides do like ion channels and polymerases.

## Membrane transport model
There is a significant attention given to ion activity with full GHK used for membrane potential
calculation and Michaelis-Menten-type substrate saturation for carrier proteins. As it stands, the
starter cell I made is unable to reach equilibrium despite weeks of work put.

## Known issues
- The cells do not reach membrane equilibrium (see Status).
- The UI is pretty limited.
- There are still many debug lines existing in the code.

## License
MIT. See [LICENSE](LICENSE).
